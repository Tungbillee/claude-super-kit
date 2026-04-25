---
name: sk:performance-testing
description: "Performance/load testing: K6 (scenarios, thresholds, custom metrics), Artillery alternative, load testing strategies (smoke/load/stress/spike/soak), results analysis, CI/CD integration. Node.js/TypeScript focused."
argument-hint: "[tool: k6|artillery] [--strategy smoke|load|stress|spike|soak] [--ci]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: testing
---

# sk:performance-testing — Performance & Load Testing

Design and run performance tests to validate system behavior under expected and peak load conditions.

## When to Use

- Pre-release validation of API performance
- Finding system breaking points (stress testing)
- Verifying SLAs (response time, error rate, throughput)
- Regression testing after infrastructure changes

## When NOT to Use

- Unit or integration testing (use Jest/Vitest)
- Functional correctness testing
- Against production without traffic throttling

---

## Load Testing Strategy Matrix

| Strategy | Load Level | Duration | Goal |
|----------|-----------|----------|------|
| Smoke | 1–5 VUs | 1–3 min | Verify test script works |
| Load | Expected peak | 10–30 min | Validate normal performance |
| Stress | 2–4× peak | 15–30 min | Find breaking point |
| Spike | Sudden 10× burst | 2–5 min | Test autoscaling / circuit breakers |
| Soak | Normal load | 2–24 h | Detect memory leaks, resource exhaustion |

---

## K6 — Basic Setup

```javascript
// tests/perf/smoke-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const error_rate = new Rate('errors');
const checkout_duration = new Trend('checkout_duration', true);  // true = display in ms

export const options = {
  // Smoke test
  vus: 2,
  duration: '1m',

  thresholds: {
    http_req_duration: ['p(95)<500'],      // 95% of requests < 500ms
    http_req_failed: ['rate<0.01'],        // < 1% error rate
    errors: ['rate<0.05'],
    checkout_duration: ['p(99)<2000'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  // GET request
  const res = http.get(`${BASE_URL}/api/products`, {
    headers: { 'Authorization': `Bearer ${__ENV.API_TOKEN}` },
    tags: { name: 'ListProducts' },
  });

  const ok = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
    'has products array': (r) => {
      try {
        return JSON.parse(r.body).products?.length > 0;
      } catch { return false; }
    },
  });

  error_rate.add(!ok);
  sleep(1);
}
```

---

## K6 — Multi-Stage Load Test

```javascript
// tests/perf/load-test.js
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { SharedArray } from 'k6/data';

// Load test data once, share across VUs
const users = new SharedArray('users', () =>
  JSON.parse(open('./data/test-users.json'))
);

export const options = {
  stages: [
    { duration: '2m',  target: 10  },  // ramp up
    { duration: '10m', target: 50  },  // sustain normal load
    { duration: '2m',  target: 100 },  // ramp to peak
    { duration: '5m',  target: 100 },  // sustain peak
    { duration: '2m',  target: 0   },  // ramp down
  ],

  thresholds: {
    'http_req_duration{name:Login}':    ['p(95)<300'],
    'http_req_duration{name:Checkout}': ['p(95)<800'],
    'http_req_duration{name:Search}':   ['p(95)<400'],
    http_req_failed: ['rate<0.02'],
  },
};

export default function () {
  const user = users[Math.floor(Math.random() * users.length)];

  group('Authentication', () => {
    const login_res = http.post(
      `${__ENV.BASE_URL}/api/auth/login`,
      JSON.stringify({ email: user.email, password: user.password }),
      { headers: { 'Content-Type': 'application/json' }, tags: { name: 'Login' } },
    );

    check(login_res, {
      'login successful': (r) => r.status === 200,
      'has access_token': (r) => !!JSON.parse(r.body).access_token,
    });

    const token = JSON.parse(login_res.body).access_token;

    group('Shopping Flow', () => {
      // Search
      http.get(`${__ENV.BASE_URL}/api/products?q=laptop`, {
        headers: { Authorization: `Bearer ${token}` },
        tags: { name: 'Search' },
      });
      sleep(0.5);

      // Checkout
      http.post(
        `${__ENV.BASE_URL}/api/checkout`,
        JSON.stringify({ cart_id: 'test-cart', payment: 'stripe' }),
        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          tags: { name: 'Checkout' } },
      );
    });
  });

  sleep(Math.random() * 2 + 1);  // think time 1–3s
}
```

---

## K6 — Spike & Stress Tests

```javascript
// tests/perf/stress-test.js
export const options = {
  stages: [
    { duration: '1m',  target: 50  },   // warm up
    { duration: '5m',  target: 200 },   // 2× normal
    { duration: '5m',  target: 400 },   // 4× normal
    { duration: '5m',  target: 600 },   // stress
    { duration: '2m',  target: 0   },   // recovery
  ],
  thresholds: {
    http_req_failed: ['rate<0.1'],       // allow 10% errors under stress
    http_req_duration: ['p(99)<5000'],   // 99% under 5s even under stress
  },
};

// tests/perf/spike-test.js
export const options = {
  stages: [
    { duration: '10s', target: 5   },   // baseline
    { duration: '1m',  target: 5   },   // steady
    { duration: '10s', target: 500 },   // sudden spike
    { duration: '3m',  target: 500 },   // hold spike
    { duration: '10s', target: 5   },   // drop back
    { duration: '2m',  target: 5   },   // recovery check
    { duration: '10s', target: 0   },
  ],
};

// tests/perf/soak-test.js
export const options = {
  stages: [
    { duration: '5m', target: 20 },    // ramp
    { duration: '4h', target: 20 },    // soak (check for memory leaks)
    { duration: '5m', target: 0  },
  ],
  thresholds: {
    http_req_failed: ['rate<0.005'],    // tighter threshold for soak
  },
};
```

---

## K6 — Custom Metrics & Scenarios

```javascript
// tests/perf/scenarios.js
export const options = {
  scenarios: {
    // Constant arrival rate (throughput-focused)
    api_throughput: {
      executor: 'constant-arrival-rate',
      rate: 100,                   // 100 iterations/second
      timeUnit: '1s',
      duration: '5m',
      preAllocatedVUs: 50,
      maxVUs: 200,
    },
    // Ramping VUs (concurrency-focused)
    browser_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [{ duration: '5m', target: 50 }],
    },
  },
};
```

---

## Artillery Alternative

```yaml
# tests/perf/artillery-load.yml
config:
  target: "http://localhost:3000"
  phases:
    - duration: 120
      arrivalRate: 10
      name: "Warm up"
    - duration: 300
      arrivalRate: 50
      name: "Sustained load"
  defaults:
    headers:
      Content-Type: "application/json"
  plugins:
    metrics-by-endpoint: {}

scenarios:
  - name: "API Flow"
    weight: 70
    flow:
      - post:
          url: "/api/auth/login"
          json:
            email: "test@example.com"
            password: "password"
          capture:
            - json: "$.access_token"
              as: "token"
      - get:
          url: "/api/products"
          headers:
            Authorization: "Bearer {{ token }}"
          expect:
            - statusCode: 200
            - contentType: json

  - name: "Health check only"
    weight: 30
    flow:
      - get:
          url: "/health"
          expect:
            - statusCode: 200
```

---

## CI/CD Integration (GitHub Actions)

```yaml
# .github/workflows/perf-test.yml
name: Performance Tests

on:
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'  # nightly

jobs:
  k6-load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Start app
        run: docker compose up -d
        timeout-minutes: 2

      - name: Wait for app
        run: |
          timeout 60 bash -c 'until curl -sf http://localhost:3000/health; do sleep 2; done'

      - name: Run K6 smoke test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: tests/perf/smoke-test.js
        env:
          BASE_URL: http://localhost:3000
          API_TOKEN: ${{ secrets.PERF_TEST_TOKEN }}

      - name: Upload K6 results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: k6-results
          path: k6-results.json
```

---

## Results Analysis

```bash
# Run with JSON output for analysis
k6 run --out json=results.json tests/perf/load-test.js

# Key metrics to check in output:
# http_req_duration{p(50), p(95), p(99)} — latency percentiles
# http_req_failed{rate}                  — error rate
# http_reqs{rate}                        — throughput (RPS)
# vus_max                                — peak concurrency
# data_received / data_sent              — bandwidth
```

**SLO thresholds to target:**
- p95 latency < 500ms (API), < 200ms (health checks)
- Error rate < 1% under normal load
- p99 latency < 2000ms under stress

---

## Checklist

- [ ] Smoke test passes before running full load test
- [ ] Test data loaded with `SharedArray` (not per-VU)
- [ ] Thresholds defined for p95 latency and error rate
- [ ] Think time (`sleep`) added between requests
- [ ] Secrets passed via `__ENV` not hardcoded
- [ ] Stages cover ramp-up, sustain, and ramp-down
- [ ] CI runs smoke test on every PR, full load test nightly

---

## References

- [K6 docs](https://k6.io/docs/)
- [K6 examples](https://github.com/grafana/k6/tree/master/examples)
- [Artillery docs](https://www.artillery.io/docs)
- [K6 thresholds](https://k6.io/docs/using-k6/thresholds/)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask for tool preference**: K6 (recommended) or Artillery?
2. **Ask about test strategy**: Smoke, load, stress, spike, or soak?
3. **Ask about target SLOs**: What are the acceptable latency/error rate thresholds?
4. **Ask about auth**: Does the API require authentication? What type?
5. **Ask about CI**: Integrate into GitHub Actions, GitLab CI, or Jenkins?

Then generate complete test scripts with appropriate stages, thresholds, and CI pipeline config.
