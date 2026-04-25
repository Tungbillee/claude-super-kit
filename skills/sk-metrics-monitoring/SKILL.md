---
name: sk:metrics-monitoring
description: "Prometheus + Grafana observability stack: metric types (counter/gauge/histogram/summary), PromQL query basics, Grafana dashboard best practices, custom metrics in Node.js/Python/Go, Alertmanager alerting rules."
argument-hint: "[language: node|python|go] [--grafana] [--alerting] [--promql]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: observability
---

# sk:metrics-monitoring — Prometheus + Grafana

Implement production metrics collection, dashboards, and alerting using the Prometheus + Grafana stack.

## When to Use

- Adding observability metrics to a service
- Creating Grafana dashboards for business/technical KPIs
- Setting up alerting rules via Alertmanager
- Understanding and writing PromQL queries

---

## Metric Types

| Type | Description | Use Case |
|------|-------------|----------|
| Counter | Monotonically increasing number | Request count, errors, bytes sent |
| Gauge | Value that can go up or down | Active connections, memory usage, queue size |
| Histogram | Bucketed observations with sum/count | Request duration, response size |
| Summary | Client-side quantiles | Latency percentiles (avoid in high-cardinality) |

**Rule:** Prefer Histogram over Summary for latency — Histograms can be aggregated across instances; Summaries cannot.

---

## Node.js Custom Metrics (prom-client)

```typescript
// src/metrics/prometheus.ts
import client from 'prom-client';

// Enable default metrics (CPU, memory, event loop lag, GC)
client.collectDefaultMetrics({
  prefix: 'app_',
  labels: {
    service: process.env.SERVICE_NAME || 'app',
    version: process.env.APP_VERSION || '0.0.0',
  },
});

// Counter
export const http_requests_total = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

// Gauge
export const active_connections = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active WebSocket connections',
  labelNames: ['type'],
});

// Histogram (recommended for latency)
export const http_request_duration_seconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
});

// Business metric
export const orders_processed_total = new client.Counter({
  name: 'orders_processed_total',
  help: 'Total orders processed',
  labelNames: ['status', 'payment_method'],
});
```

```typescript
// src/metrics/express-middleware.ts
import { Request, Response, NextFunction } from 'express';
import {
  http_requests_total,
  http_request_duration_seconds,
} from './prometheus';

export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const end = http_request_duration_seconds.startTimer();

  res.on('finish', () => {
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status_code: String(res.statusCode),
    };
    http_requests_total.inc(labels);
    end(labels);
  });

  next();
}

// Metrics endpoint
export function metricsHandler(req: Request, res: Response) {
  res.set('Content-Type', client.register.contentType);
  client.register.metrics().then(m => res.end(m));
}
```

---

## Python Custom Metrics (prometheus-client)

```python
# src/metrics/prometheus.py
from prometheus_client import Counter, Gauge, Histogram, start_http_server, CollectorRegistry

REGISTRY = CollectorRegistry()

http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code'],
    registry=REGISTRY,
)

request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'Request duration',
    ['method', 'endpoint'],
    buckets=[.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5],
    registry=REGISTRY,
)

# FastAPI middleware
from fastapi import Request
import time

async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    duration = time.perf_counter() - start

    labels = {'method': request.method, 'endpoint': request.url.path}
    http_requests_total.labels(**labels, status_code=str(response.status_code)).inc()
    request_duration_seconds.labels(**labels).observe(duration)

    return response
```

---

## Go Custom Metrics (prometheus/client_golang)

```go
// internal/metrics/prometheus.go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    HttpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "path", "status"},
    )

    HttpDurationSeconds = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request latency",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path"},
    )

    ActiveWorkers = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "worker_active_count",
        Help: "Currently active workers",
    })
)
```

---

## Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: production

scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['app:3000']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

rule_files:
  - '/etc/prometheus/rules/*.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

---

## PromQL Basics

```promql
# Request rate (per second, 5m window)
rate(http_requests_total[5m])

# Error rate percentage
sum(rate(http_requests_total{status_code=~"5.."}[5m]))
/ sum(rate(http_requests_total[5m])) * 100

# p99 latency
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le, route)
)

# Active connections by type
active_connections{type="websocket"}

# Memory usage MB
process_resident_memory_bytes / 1024 / 1024

# Aggregated across instances
sum by (route) (rate(http_requests_total[5m]))
```

---

## Alertmanager Rules

```yaml
# /etc/prometheus/rules/app-alerts.yml
groups:
  - name: app_alerts
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status_code=~"5.."}[5m]))
          / sum(rate(http_requests_total[5m])) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate: {{ $value | humanizePercentage }}"
          runbook_url: "https://wiki/runbooks/high-error-rate"

      - alert: HighLatencyP99
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) > 1.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "p99 latency {{ $value }}s exceeds 1s threshold"

      - alert: ServiceDown
        expr: up{job="app"} == 0
        for: 1m
        labels:
          severity: critical
```

```yaml
# alertmanager.yml
global:
  slack_api_url: 'https://hooks.slack.com/services/...'

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  receiver: 'slack-critical'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'

receivers:
  - name: 'slack-critical'
    slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

---

## Grafana Dashboard Best Practices

```json
// Dashboard panel template (JSON)
{
  "title": "Request Rate",
  "type": "timeseries",
  "targets": [{
    "expr": "sum(rate(http_requests_total[5m])) by (route)",
    "legendFormat": "{{route}}"
  }],
  "fieldConfig": {
    "defaults": {
      "unit": "reqps",
      "thresholds": {
        "steps": [
          {"color": "green", "value": null},
          {"color": "yellow", "value": 100},
          {"color": "red", "value": 500}
        ]
      }
    }
  }
}
```

**Dashboard design rules:**
- Top row: SLI metrics (error rate, latency, availability)
- Second row: Traffic (RPS, active users)
- Third row: Resources (CPU, memory, DB connections)
- Use `rate()` not `increase()` for counters on dashboards
- Set `min: 0` on all panels showing rates
- Add annotations for deployments (mark incidents on timeline)

---

## Docker Compose Stack

```bash
# Quick start: prom/prometheus:v2.50.0 on :9090
#              grafana/grafana:10.3.0 on :3001
#              prom/alertmanager:v0.26.0 on :9093
# Mount prometheus.yml, rules/, alertmanager.yml as volumes.
```

---

## Checklist

- [ ] Default metrics enabled (`collectDefaultMetrics`)
- [ ] HTTP duration histogram with appropriate buckets
- [ ] Business KPI counters defined
- [ ] Prometheus scraping service `/metrics` endpoint
- [ ] Alert rules for error rate, latency, availability
- [ ] Alertmanager configured with Slack/PagerDuty receiver
- [ ] Grafana dashboard with SLI row at top

---

## References

- [Prometheus docs](https://prometheus.io/docs/)
- [prom-client Node.js](https://github.com/siimon/prom-client)
- [PromQL cheatsheet](https://promlabs.com/promql-cheat-sheet/)
- [Grafana dashboards](https://grafana.com/grafana/dashboards/)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask about language/framework**: Node.js, Python FastAPI, or Go?
2. **Ask what to measure**: HTTP requests, background jobs, DB queries, business events?
3. **Ask about alerting needs**: Slack? PagerDuty? What thresholds?
4. **Ask if Grafana dashboards needed**: Which KPIs matter most?

Then generate complete metrics setup including middleware, Prometheus config, alert rules, and Docker Compose stack.
