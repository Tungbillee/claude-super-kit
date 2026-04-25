---
name: sk:distributed-tracing
description: "Distributed tracing setup: OpenTelemetry (auto + manual instrumentation), Jaeger/Zipkin backends, trace context propagation across services, sampling strategies, exemplars linking traces to metrics. Node.js/TypeScript focused."
argument-hint: "[--otel] [--jaeger] [--zipkin] [--manual] [--sampling]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: observability
---

# sk:distributed-tracing — Distributed Tracing

Implement end-to-end distributed tracing across microservices using OpenTelemetry with Jaeger or Zipkin as backend.

## When to Use

- Diagnosing latency issues across microservices
- Understanding request flow through distributed systems
- Correlating errors with specific service hops
- Root cause analysis for intermittent failures

## When NOT to Use

- Single-service monolith (use APM profiling instead)
- Simple scripts or CLI tools

---

## OpenTelemetry Auto-Instrumentation (Node.js)

```typescript
// src/tracing/otel-setup.ts  — MUST be imported first in main entry
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from '@opentelemetry/semantic-conventions';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { TraceIdRatioBased } from '@opentelemetry/sdk-trace-base';

const exporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces',
});

const sdk = new NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: process.env.SERVICE_NAME || 'my-service',
    [ATTR_SERVICE_VERSION]: process.env.APP_VERSION || '0.0.0',
    'deployment.environment': process.env.NODE_ENV || 'development',
  }),
  traceExporter: exporter,
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': { enabled: true },
      '@opentelemetry/instrumentation-express': { enabled: true },
      '@opentelemetry/instrumentation-pg': { enabled: true },
      '@opentelemetry/instrumentation-redis': { enabled: true },
      '@opentelemetry/instrumentation-grpc': { enabled: true },
    }),
  ],
  sampler: new TraceIdRatioBased(
    process.env.NODE_ENV === 'production' ? 0.1 : 1.0  // 10% in prod
  ),
});

sdk.start();

process.on('SIGTERM', () => sdk.shutdown());
```

```typescript
// src/main.ts — tracing MUST be first import
import './tracing/otel-setup';  // before everything else
import express from 'express';
// ... rest of app
```

---

## Manual Instrumentation — Custom Spans

```typescript
// src/tracing/tracer.ts
import { trace, context, SpanStatusCode, SpanKind } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service', '1.0.0');

// Wrap async operations with custom spans
export async function withSpan<T>(
  span_name: string,
  operation: () => Promise<T>,
  attributes?: Record<string, string | number | boolean>,
): Promise<T> {
  return tracer.startActiveSpan(span_name, { attributes }, async (span) => {
    try {
      const result = await operation();
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (err) {
      span.recordException(err as Error);
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: (err as Error).message,
      });
      throw err;
    } finally {
      span.end();
    }
  });
}

// Usage in service
export async function processOrder(order_id: string) {
  return withSpan('order.process', async () => {
    const span = trace.getActiveSpan();
    span?.setAttributes({
      'order.id': order_id,
      'order.source': 'api',
    });

    // child span for DB call
    return withSpan('order.db.fetch', () => db.orders.findById(order_id));
  });
}
```

---

## Trace Context Propagation (HTTP)

```typescript
// src/http/traced-client.ts
import axios from 'axios';
import { context, propagation } from '@opentelemetry/api';

export function createTracedClient() {
  const client = axios.create();

  // Inject trace context into outgoing requests
  client.interceptors.request.use((config) => {
    const headers: Record<string, string> = {};
    propagation.inject(context.active(), headers);
    Object.assign(config.headers, headers);
    return config;
  });

  return client;
}

// Express middleware to extract incoming trace context
export function traceExtractionMiddleware(
  req: Request, res: Response, next: NextFunction
) {
  const extracted_context = propagation.extract(context.active(), req.headers);
  context.with(extracted_context, next);
}
```

---

## Jaeger Backend Setup

```yaml
# docker-compose.yml
services:
  jaeger:
    image: jaegertracing/all-in-one:1.56
    ports:
      - "16686:16686"   # Jaeger UI
      - "4317:4317"     # OTLP gRPC
      - "4318:4318"     # OTLP HTTP
    environment:
      - COLLECTOR_OTLP_ENABLED=true
      - SPAN_STORAGE_TYPE=memory   # use elasticsearch for production
```

**Production Jaeger with Elasticsearch:**

```yaml
services:
  jaeger-collector:
    image: jaegertracing/jaeger-collector:1.56
    environment:
      - SPAN_STORAGE_TYPE=elasticsearch
      - ES_SERVER_URLS=http://elasticsearch:9200
      - SAMPLING_STRATEGIES_FILE=/etc/jaeger/sampling.json

  jaeger-query:
    image: jaegertracing/jaeger-query:1.56
    ports: ["16686:16686"]
```

---

## Zipkin Alternative

```typescript
// src/tracing/zipkin-setup.ts
import { ZipkinExporter } from '@opentelemetry/exporter-zipkin';

const zipkin_exporter = new ZipkinExporter({
  url: process.env.ZIPKIN_URL || 'http://localhost:9411/api/v2/spans',
  serviceName: process.env.SERVICE_NAME || 'my-service',
});

// Use in NodeSDK: traceExporter: zipkin_exporter
```

```yaml
# docker-compose.yml
services:
  zipkin:
    image: openzipkin/zipkin:3
    ports: ["9411:9411"]
```

---

## Sampling Strategies

```typescript
import {
  TraceIdRatioBased,
  ParentBasedSampler,
  AlwaysOnSampler,
  AlwaysOffSampler,
} from '@opentelemetry/sdk-trace-base';

// Parent-based: respect upstream sampling decision
const sampler = new ParentBasedSampler({
  root: new TraceIdRatioBased(0.1),       // 10% of new traces
  remoteParentSampled: new AlwaysOnSampler(),    // always if upstream sampled
  remoteParentNotSampled: new AlwaysOffSampler(), // never if upstream didn't
});
```

**Sampling guidelines:**
- Development: `AlwaysOnSampler` (100%)
- Staging: `TraceIdRatioBased(0.5)` (50%)
- Production: `ParentBasedSampler` + `TraceIdRatioBased(0.05–0.1)` (5–10%)
- High-volume endpoints: lower ratio or head-based sampling

---

## Exemplars (Linking Metrics to Traces)

```typescript
// src/metrics/exemplars.ts
import { trace } from '@opentelemetry/api';
import { Counter, Histogram } from 'prom-client';

// Prometheus exemplars attach trace_id to metric observations
const http_duration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status'],
  enableExemplars: true,
});

export function recordRequestDuration(
  method: string, route: string, status: number, duration_s: number
) {
  const span = trace.getActiveSpan();
  const span_context = span?.spanContext();

  http_duration.observe(
    { method, route, status: String(status) },
    duration_s,
    span_context ? {
      traceId: span_context.traceId,
      spanId: span_context.spanId,
    } : undefined,
  );
}
```

---

## Span Attributes — Semantic Conventions

```typescript
// Follow OpenTelemetry semantic conventions
span.setAttributes({
  // HTTP
  'http.method': 'POST',
  'http.url': 'https://api.example.com/orders',
  'http.status_code': 200,

  // Database
  'db.system': 'postgresql',
  'db.name': 'orders_db',
  'db.operation': 'SELECT',

  // Messaging
  'messaging.system': 'rabbitmq',
  'messaging.destination': 'orders.created',
  'messaging.operation': 'publish',

  // Custom business
  'business.order_id': order_id,
  'business.user_id': user_id,
});
```

---

## Checklist

- [ ] `otel-setup.ts` imported as first line of `main.ts`
- [ ] `SERVICE_NAME` env var set per service
- [ ] Trace context headers propagated on all outgoing HTTP/gRPC calls
- [ ] Custom spans added for business-critical operations
- [ ] Sampling rate configured per environment
- [ ] Jaeger or Zipkin backend running and accessible
- [ ] Error recording via `span.recordException()` in catch blocks
- [ ] Semantic conventions followed for span attributes

---

## References

- [OpenTelemetry Node.js](https://opentelemetry.io/docs/languages/js/)
- [Jaeger docs](https://www.jaegertracing.io/docs/)
- [OTel Semantic Conventions](https://opentelemetry.io/docs/concepts/semantic-conventions/)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask for backend preference**: Jaeger or Zipkin? Or cloud (Datadog/Honeycomb/Tempo)?
2. **Ask about framework**: Express, Fastify, NestJS, gRPC?
3. **Ask about service count**: Single service or multiple microservices needing context propagation?
4. **Ask about sampling needs**: Traffic volume estimate to recommend sampling ratio

Then generate complete tracing setup with correct SDK config, middleware, and Docker Compose for chosen backend.
