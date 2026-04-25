---
name: sk:structured-logging
description: "Structured logging setup and best practices: Winston (transports, formats, levels), Pino (fast JSON), Bunyan, ELK stack integration, correlation/trace ID propagation, log level guidance. For Node.js/TypeScript backend observability."
argument-hint: "[library: winston|pino|bunyan] [--elk] [--correlation] [--levels]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: observability
---

# sk:structured-logging — Structured Logging

Implement production-grade structured logging with correlation ID propagation, ELK stack integration, and proper log level usage.

## When to Use

- Setting up logging in a new Node.js/TypeScript service
- Migrating from `console.log` to structured logs
- Integrating with ELK/OpenSearch stack
- Adding request tracing across microservices

## When NOT to Use

- Frontend browser logging (use Sentry/Datadog RUM instead)
- Simple scripts where `console.log` suffices

---

## Library Comparison

| Library | Speed | Format | Best For |
|---------|-------|--------|----------|
| Winston | Medium | JSON/text | Flexibility, multiple transports |
| Pino | Fast | JSON only | High-throughput services |
| Bunyan | Medium | JSON | Child loggers, serializers |

---

## Winston Setup

```typescript
// src/logger/winston.ts
import winston from 'winston';

const { combine, timestamp, json, errors, colorize, simple } = winston.format;

const LOG_LEVELS = {
  error: 0, warn: 1, info: 2, http: 3, debug: 4,
};

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  levels: LOG_LEVELS,
  format: combine(
    errors({ stack: true }),       // capture stack traces
    timestamp({ format: 'ISO' }),
    json(),
  ),
  defaultMeta: {
    service: process.env.SERVICE_NAME || 'app',
    version: process.env.APP_VERSION || '0.0.0',
    env: process.env.NODE_ENV,
  },
  transports: [
    new winston.transports.Console({
      format: process.env.NODE_ENV === 'production'
        ? combine(timestamp(), json())
        : combine(colorize(), simple()),
    }),
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
      tailable: true,
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 50 * 1024 * 1024, // 50MB
      maxFiles: 10,
    }),
  ],
  exitOnError: false,
});
```

### Winston HTTP Transport (ELK)

```typescript
// src/logger/elk-transport.ts
import WinstonElasticsearch from 'winston-elasticsearch';

logger.add(new WinstonElasticsearch({
  level: 'info',
  clientOpts: { node: process.env.ELASTICSEARCH_URL },
  indexPrefix: 'app-logs',
  indexSuffixPattern: 'YYYY.MM.DD',
  messageType: '_doc',
}));
```

---

## Pino Setup (Recommended for High Throughput)

```typescript
// src/logger/pino.ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: {
    pid: process.pid,
    service: process.env.SERVICE_NAME,
    version: process.env.APP_VERSION,
  },
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
  serializers: {
    err: pino.stdSerializers.err,
    req: pino.stdSerializers.req,
    res: pino.stdSerializers.res,
  },
  redact: {
    paths: ['req.headers.authorization', 'body.password', '*.token'],
    censor: '[REDACTED]',
  },
});
```

---

## Correlation ID Propagation

```typescript
// src/middleware/correlation.middleware.ts
import { AsyncLocalStorage } from 'node:async_hooks';
import { randomUUID } from 'node:crypto';

interface TraceContext {
  correlation_id: string;
  trace_id?: string;
  span_id?: string;
  user_id?: string;
}

export const trace_storage = new AsyncLocalStorage<TraceContext>();

// Express middleware
export function correlationMiddleware(req: Request, res: Response, next: NextFunction) {
  const correlation_id =
    (req.headers['x-correlation-id'] as string) ||
    (req.headers['x-request-id'] as string) ||
    randomUUID();

  const ctx: TraceContext = {
    correlation_id,
    trace_id: req.headers['x-trace-id'] as string,
  };

  res.setHeader('x-correlation-id', correlation_id);

  trace_storage.run(ctx, () => next());
}

// Logger factory that auto-injects trace context
export function getLogger(module_name: string) {
  const ctx = trace_storage.getStore();
  return logger.child({
    module: module_name,
    ...ctx,
  });
}
```

### Usage in Services

```typescript
// src/services/user.service.ts
import { getLogger } from '../middleware/correlation.middleware';

export async function getUserById(user_id: string) {
  const log = getLogger('UserService');

  log.info({ user_id }, 'Fetching user');

  try {
    const user = await db.users.findById(user_id);
    log.info({ user_id, found: !!user }, 'User fetch complete');
    return user;
  } catch (err) {
    log.error({ err, user_id }, 'Failed to fetch user');
    throw err;
  }
}
```

---

## Log Level Guidance

| Level | When to Use | Example |
|-------|-------------|---------|
| `error` | Unrecoverable errors requiring attention | DB connection fail, unhandled exception |
| `warn` | Recoverable but unexpected | Deprecated API call, retry attempt |
| `info` | Normal business events | User login, order created |
| `http` | HTTP request/response | Request duration, status code |
| `debug` | Detailed diagnostic (dev only) | SQL query, internal state |

**Rules:**
- Production: `info` level minimum
- Never log passwords, tokens, PII without redaction
- Always log `correlation_id` on every line
- Include `err.stack` for errors (use serializers)

---

## ELK Stack Integration

```yaml
# docker-compose.yml
services:
  elasticsearch:
    image: elasticsearch:8.12.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports: ["9200:9200"]

  logstash:
    image: logstash:8.12.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline

  kibana:
    image: kibana:8.12.0
    ports: ["5601:5601"]
```

```ruby
# logstash/pipeline/app.conf
input {
  beats { port => 5044 }
}
filter {
  json { source => "message" }
  mutate {
    add_field => { "[@metadata][index]" => "app-logs-%{+YYYY.MM.dd}" }
  }
}
output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "%{[@metadata][index]}"
  }
}
```

---

## Structured Fields Best Practices

```typescript
// GOOD — structured, searchable
log.info({ user_id, order_id, amount_cents: 4999 }, 'Payment processed');

// BAD — unstructured string
log.info(`Payment for user ${user_id} order ${order_id} amount $49.99 processed`);

// GOOD — error with context
log.error({ err, user_id, operation: 'payment' }, 'Payment failed');

// GOOD — performance measurement
const start = Date.now();
await processOrder(order);
log.info({ duration_ms: Date.now() - start, order_id }, 'Order processed');
```

---

## Checklist

- [ ] Logger initialized with `service` + `version` in `defaultMeta`
- [ ] Correlation middleware attached before route handlers
- [ ] `AsyncLocalStorage` used for trace context propagation
- [ ] PII/tokens redacted via `redact` config
- [ ] Error serializers configured (`err.stack` captured)
- [ ] Log levels match environment (debug in dev, info in prod)
- [ ] ELK transport added for centralized log aggregation

---

## References

- [Winston docs](https://github.com/winstonjs/winston)
- [Pino docs](https://getpino.io/)
- [Node AsyncLocalStorage](https://nodejs.org/api/async_context.html)
- [ELK Stack docs](https://www.elastic.co/guide/index.html)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask which library** the user wants: Winston, Pino, or Bunyan
2. **Ask about transport needs**: console only, file, ELK/OpenSearch, or cloud (Datadog/CloudWatch)
3. **Ask about correlation ID**: Is this a microservices setup needing trace propagation?
4. **Confirm redaction needs**: What sensitive fields need to be redacted?

Then generate complete, working logger setup tailored to their stack. Include correlation middleware if microservices. Include ELK config if centralized logging requested.
