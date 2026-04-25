---
name: sk:apm-profiling
description: "APM and application profiling: DataDog APM setup, New Relic alternative, CPU/memory profiling in Node.js, distributed transaction tracing, slow query detection, flame graph analysis, transaction tracing."
argument-hint: "[provider: datadog|newrelic|custom] [--profiling] [--slowquery] [--flamegraph]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: observability
---

# sk:apm-profiling — APM & Application Profiling

Full application performance monitoring: distributed tracing, CPU/memory profiling, slow query detection, and transaction analysis.

## When to Use

- Diagnosing unexplained latency or high CPU/memory usage
- Finding slow database queries in production
- Profiling Node.js applications for performance bottlenecks
- Setting up end-to-end transaction tracing with vendor APM

---

## DataDog APM Setup (Node.js)

```typescript
// src/apm/datadog.ts — MUST be first import in main entry
import tracer from 'dd-trace';

tracer.init({
  hostname: process.env.DD_AGENT_HOST || 'localhost',
  port: 4318,
  service: process.env.DD_SERVICE || 'my-service',
  env: process.env.DD_ENV || process.env.NODE_ENV,
  version: process.env.DD_VERSION || process.env.APP_VERSION,

  // Tracing config
  sampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  logInjection: true,   // auto-inject trace IDs into logs

  // Profiling (continuous profiler)
  profiling: process.env.DD_PROFILING_ENABLED === 'true',

  // Runtimemetrics
  runtimeMetrics: true,

  // Slow query detection
  dbmPropagation: 'full',  // inject trace context into DB queries
});

export { tracer };
```

```typescript
// src/main.ts
import './apm/datadog';  // FIRST line — before all other imports
import express from 'express';
```

### DataDog Manual Spans

```typescript
import { tracer } from './apm/datadog';

// Wrap operation with custom span
async function processCheckout(cart_id: string, user_id: string) {
  const span = tracer.startSpan('checkout.process', {
    childOf: tracer.scope().active() ?? undefined,
    tags: {
      'cart.id': cart_id,
      'user.id': user_id,
      'resource.name': 'checkout',
    },
  });

  try {
    const result = await doCheckout(cart_id);
    span.setTag('checkout.total_cents', result.total_cents);
    span.setTag('span.kind', 'internal');
    return result;
  } catch (err) {
    span.setTag('error', true);
    span.setTag('error.message', (err as Error).message);
    span.log({ error: err });
    throw err;
  } finally {
    span.finish();
  }
}
```

### DataDog Agent (Docker)

```yaml
# docker-compose.yml
services:
  datadog-agent:
    image: gcr.io/datadoghq/agent:7
    environment:
      - DD_API_KEY=${DD_API_KEY}
      - DD_APM_ENABLED=true
      - DD_APM_NON_LOCAL_TRAFFIC=true
      - DD_LOGS_ENABLED=true
      - DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
      - DD_PROCESS_AGENT_ENABLED=true
      - DD_PROFILING_ENABLED=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc/:/host/proc/:ro
      - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
    ports:
      - "4318:4318"
```

---

## New Relic Alternative

```typescript
// src/apm/newrelic.ts
// newrelic must be required before other modules
require('newrelic');  // CommonJS only — package reads newrelic.js config

// newrelic.js config
module.exports = {
  app_name: [process.env.NEW_RELIC_APP_NAME || 'My App'],
  license_key: process.env.NEW_RELIC_LICENSE_KEY,
  distributed_tracing: { enabled: true },
  logging: {
    level: 'info',
    enabled: true,
  },
  slow_sql: {
    enabled: true,
    max_samples: 10,
  },
  transaction_tracer: {
    record_sql: 'obfuscated',
    explain_threshold: 200,  // log query plan if > 200ms
  },
};
```

---

## Node.js CPU Profiling (Built-in)

```typescript
// src/profiling/cpu-profiler.ts
import { createServer } from 'http';
import { Session } from 'inspector';
import { writeFileSync } from 'fs';

export class CpuProfiler {
  private session = new Session();
  private is_profiling = false;

  async start(duration_ms = 30_000): Promise<void> {
    if (this.is_profiling) return;

    this.session.connect();
    await this.session.post('Profiler.enable');
    await this.session.post('Profiler.start');
    this.is_profiling = true;

    setTimeout(() => this.stop(), duration_ms);
    console.log(`CPU profiling started for ${duration_ms}ms`);
  }

  async stop(): Promise<string> {
    if (!this.is_profiling) return '';

    const { profile } = await this.session.post('Profiler.stop') as { profile: object };
    const file_path = `profiles/cpu-${Date.now()}.cpuprofile`;
    writeFileSync(file_path, JSON.stringify(profile));
    this.session.disconnect();
    this.is_profiling = false;

    console.log(`CPU profile saved: ${file_path}`);
    return file_path;
  }
}

// Expose via admin HTTP endpoint (secured)
export function registerProfilerEndpoints(app: Express) {
  const profiler = new CpuProfiler();

  app.post('/admin/profiling/cpu/start', adminAuth, async (req, res) => {
    const { duration_ms = 30_000 } = req.body;
    await profiler.start(duration_ms);
    res.json({ status: 'started', duration_ms });
  });

  app.post('/admin/profiling/cpu/stop', adminAuth, async (req, res) => {
    const file_path = await profiler.stop();
    res.json({ status: 'stopped', file_path });
  });
}
```

---

## Memory Profiling (Heap Snapshots)

```typescript
// src/profiling/heap-profiler.ts
import v8 from 'v8';
import { writeFileSync, mkdirSync } from 'fs';
import { Session } from 'inspector';

export async function captureHeapSnapshot(): Promise<string> {
  const session = new Session();
  session.connect();

  const chunks: Buffer[] = [];

  session.on('HeapProfiler.addHeapSnapshotChunk', ({ params }) => {
    chunks.push(Buffer.from(params.chunk));
  });

  await new Promise<void>((resolve, reject) => {
    session.post('HeapProfiler.takeHeapSnapshot', { reportProgress: false }, (err) => {
      err ? reject(err) : resolve();
    });
  });

  mkdirSync('profiles', { recursive: true });
  const file_path = `profiles/heap-${Date.now()}.heapsnapshot`;
  writeFileSync(file_path, Buffer.concat(chunks));
  session.disconnect();

  return file_path;
}

// Memory leak detection
export function watchMemory(threshold_mb = 512, interval_ms = 60_000) {
  setInterval(() => {
    const { rss, heapUsed } = process.memoryUsage();
    const heap_mb = heapUsed / 1024 / 1024;
    const rss_mb = rss / 1024 / 1024;

    if (heap_mb > threshold_mb) {
      console.error({ heap_mb, rss_mb, threshold_mb }, 'Memory threshold exceeded');
      captureHeapSnapshot().then(path => console.log('Heap snapshot saved', path));
    }
  }, interval_ms);
}
```

---

## Slow Query Detection

```typescript
// src/database/slow-query-logger.ts
import { Pool } from 'pg';
import { getLogger } from '../logger';

const SLOW_QUERY_THRESHOLD_MS = 200;

export function createInstrumentedPool(config: PoolConfig): Pool {
  const pool = new Pool(config);
  const log = getLogger('database');

  // Monkey-patch query to add timing
  const original_query = pool.query.bind(pool);

  pool.query = async function instrumentedQuery(
    text: string,
    params?: unknown[],
  ) {
    const start = Date.now();
    try {
      const result = await original_query(text, params);
      const duration_ms = Date.now() - start;

      if (duration_ms > SLOW_QUERY_THRESHOLD_MS) {
        log.warn({ duration_ms, query: text.substring(0, 200) }, 'Slow query detected');
      } else {
        log.debug({ duration_ms }, 'Query executed');
      }

      return result;
    } catch (err) {
      log.error({ err, query: text.substring(0, 200) }, 'Query failed');
      throw err;
    }
  };

  return pool;
}
```

---

## Flame Graph Generation (Clinic.js)

```bash
# Install clinic
npm install -g clinic

# CPU profiling + flame graph
clinic flame -- node dist/server.js

# Bubble chart (async operations)
clinic bubbles -- node dist/server.js

# Doctor (comprehensive analysis)
clinic doctor -- node dist/server.js

# Generate under load (run clinic with autocannon load)
clinic flame -- node dist/server.js &
autocannon -c 100 -d 30 http://localhost:3000/api/endpoint
```

**Reading flame graphs:**
- Wide flat tops = hot path, optimize here
- Tall narrow spikes = deep call stacks, refactor
- `node_modules` frames at top = dependency bottleneck

---

## Performance Regression Detection

```typescript
// src/profiling/perf-baseline.ts
import { performance, PerformanceObserver } from 'perf_hooks';

// Mark and measure critical operations
export function measureOperation(name: string) {
  return function decorator(
    target: object,
    property_key: string,
    descriptor: PropertyDescriptor,
  ) {
    const original = descriptor.value;
    descriptor.value = async function (...args: unknown[]) {
      const mark_start = `${name}-start`;
      const mark_end = `${name}-end`;
      performance.mark(mark_start);

      const result = await original.apply(this, args);

      performance.mark(mark_end);
      performance.measure(name, mark_start, mark_end);
      return result;
    };
    return descriptor;
  };
}

// Observer to collect measurements
const obs = new PerformanceObserver((items) => {
  items.getEntries().forEach(entry => {
    metrics.histogram(`operation_duration_ms`, entry.duration, { operation: entry.name });
  });
});
obs.observe({ entryTypes: ['measure'] });
```

---

## Checklist

- [ ] APM SDK initialized as first import in entry file
- [ ] `DD_SERVICE`, `DD_ENV`, `DD_VERSION` env vars set
- [ ] Log injection enabled (trace IDs in logs)
- [ ] CPU profiler endpoint secured behind admin auth
- [ ] Memory watch active with automatic heap snapshot on threshold
- [ ] Slow query threshold configured (default 200ms)
- [ ] Flame graph baseline captured before optimization

---

## References

- [DataDog Node.js APM](https://docs.datadoghq.com/tracing/trace_collection/dd_libraries/nodejs/)
- [New Relic Node.js](https://docs.newrelic.com/docs/apm/agents/nodejs-agent/)
- [Node.js Inspector API](https://nodejs.org/api/inspector.html)
- [Clinic.js](https://clinicjs.org/)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask for APM provider**: DataDog, New Relic, or open-source (OTel + Jaeger)?
2. **Ask about profiling needs**: CPU bottleneck, memory leak investigation, or slow queries?
3. **Ask about environment**: Containerized (Docker/K8s) or bare metal?
4. **Ask about existing logging**: Winston/Pino already set up? (for log injection config)

Then generate complete APM setup with correct initialization order, profiling endpoints, and slow query instrumentation.
