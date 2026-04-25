---
name: sk:error-tracking
description: "Error tracking integration: Sentry (Node/browser/mobile), Rollbar, BugSnag alternatives, error grouping strategies, sourcemap upload, release tracking, performance monitoring. Covers SDK setup, filtering, and alerting config."
argument-hint: "[platform: node|browser|react|mobile] [provider: sentry|rollbar|bugsnag] [--sourcemaps] [--release]"
metadata:
  author: Claude Super Kit
  namespace: sk
  version: "1.0.0"
  last_updated: "2026-04-25"
  license: MIT
  category: observability
---

# sk:error-tracking — Error Tracking

Integrate production error tracking to capture, group, and alert on application errors across Node.js, browser, and mobile platforms.

## When to Use

- Setting up error visibility for a new service or app
- Debugging production errors without direct log access
- Tracking error rates and release impact
- Monitoring JavaScript exceptions in browser/mobile

---

## Provider Comparison

| Feature | Sentry | Rollbar | BugSnag |
|---------|--------|---------|---------|
| Free tier | 5k errors/mo | 5k errors/mo | 7.5k errors/mo |
| Source maps | Yes | Yes | Yes |
| Performance | Yes | No | Limited |
| Session replay | Yes | No | No |
| Mobile SDK | Yes | Yes | Yes |
| Self-hosted | Yes | No | No |

---

## Sentry — Node.js Setup

```typescript
// src/monitoring/sentry.ts — import FIRST in main entry
import * as Sentry from '@sentry/node';
import { nodeProfilingIntegration } from '@sentry/profiling-node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.APP_VERSION,  // e.g. 'my-app@2.1.0'

  // Performance monitoring
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  profilesSampleRate: 0.1,

  integrations: [
    nodeProfilingIntegration(),
  ],

  // Filter out noise
  ignoreErrors: [
    'ResizeObserver loop limit exceeded',
    /Network request failed/,
  ],
  denyUrls: [
    /extensions\//i,
    /^chrome:\/\//i,
  ],

  beforeSend(event, hint) {
    // Scrub sensitive data
    if (event.request?.data) {
      const data = event.request.data as Record<string, unknown>;
      if (data.password) data.password = '[REDACTED]';
      if (data.token) data.token = '[REDACTED]';
    }
    return event;
  },
});

export { Sentry };
```

### Express Integration

```typescript
// src/app.ts
import './monitoring/sentry';  // must be first
import * as Sentry from '@sentry/node';
import express from 'express';

const app = express();

// Sentry request handler BEFORE all routes
app.use(Sentry.Handlers.requestHandler());
app.use(Sentry.Handlers.tracingHandler());

// ... routes ...

// Sentry error handler AFTER all routes
app.use(Sentry.Handlers.errorHandler({
  shouldHandleError(error) {
    return (error.status ?? 500) >= 500;
  },
}));
```

### Manual Error Capture

```typescript
import * as Sentry from '@sentry/node';

// Capture exception with context
try {
  await processPayment(order_id);
} catch (err) {
  Sentry.withScope((scope) => {
    scope.setUser({ id: user_id, email: user_email });
    scope.setTag('payment.provider', 'stripe');
    scope.setContext('order', { order_id, amount_cents });
    scope.setLevel('error');
    Sentry.captureException(err);
  });
  throw err;
}

// Capture message (warning/info)
Sentry.captureMessage('Deprecated API endpoint called', {
  level: 'warning',
  tags: { endpoint: '/api/v1/legacy' },
});

// Set user context globally (e.g., after auth)
Sentry.setUser({ id: user.id, email: user.email });
```

---

## Sentry — Browser (React)

```typescript
// src/monitoring/sentry-browser.ts
import * as Sentry from '@sentry/react';
import { BrowserTracing } from '@sentry/tracing';

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  release: __APP_VERSION__,  // injected by build tool

  integrations: [
    new BrowserTracing({
      tracePropagationTargets: ['localhost', /^https:\/\/api\.myapp\.com/],
    }),
    new Sentry.Replay({
      maskAllText: true,        // mask PII in session replays
      blockAllMedia: false,
    }),
  ],

  tracesSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,   // always capture replay on error
  replaysSessionSampleRate: 0.05,  // 5% of normal sessions

  beforeSend(event) {
    if (import.meta.env.DEV) return null;  // don't send in development
    return event;
  },
});

// React Error Boundary
export const SentryErrorBoundary = Sentry.ErrorBoundary;
```

```tsx
// src/App.tsx
import { SentryErrorBoundary } from './monitoring/sentry-browser';

function App() {
  return (
    <SentryErrorBoundary
      fallback={({ error, resetError }) => (
        <ErrorFallback error={error} onReset={resetError} />
      )}
    >
      <Router />
    </SentryErrorBoundary>
  );
}
```

---

## Sourcemap Upload

```bash
# Install Sentry CLI
npm install --save-dev @sentry/cli

# .sentryclirc
[defaults]
org = my-org
project = my-project
url = https://sentry.io/
```

```javascript
// vite.config.ts
import { sentryVitePlugin } from '@sentry/vite-plugin';

export default {
  plugins: [
    sentryVitePlugin({
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      authToken: process.env.SENTRY_AUTH_TOKEN,
      sourcemaps: {
        assets: './dist/**',
        ignore: ['node_modules'],
        deleteFilesAfterUpload: './dist/**/*.map',  // don't serve maps publicly
      },
      release: {
        name: process.env.npm_package_version,
        setCommits: { auto: true },
        deploy: {
          env: process.env.NODE_ENV,
        },
      },
    }),
  ],
  build: { sourcemap: true },
};
```

---

## Release Tracking

```bash
# CI/CD pipeline (GitHub Actions)
- name: Create Sentry release
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
  run: |
    npx sentry-cli releases new "${{ github.sha }}"
    npx sentry-cli releases set-commits "${{ github.sha }}" --auto
    npx sentry-cli releases finalize "${{ github.sha }}"
    npx sentry-cli releases deploys "${{ github.sha }}" new -e production
```

---

## Rollbar Alternative

```typescript
// src/monitoring/rollbar.ts
import Rollbar from 'rollbar';

export const rollbar = new Rollbar({
  accessToken: process.env.ROLLBAR_TOKEN,
  environment: process.env.NODE_ENV,
  codeVersion: process.env.APP_VERSION,
  captureUncaught: true,
  captureUnhandledRejections: true,
  ignoredMessages: [/ECONNREFUSED/],
  person: {
    // Set dynamically in middleware
    id: undefined,
    email: undefined,
  },
  transform(payload) {
    if (payload.body?.trace?.extra?.password) {
      payload.body.trace.extra.password = '[REDACTED]';
    }
  },
});
```

---

## Error Grouping Strategies

```typescript
// Custom fingerprinting to control error grouping
Sentry.init({
  beforeSend(event, hint) {
    const err = hint.originalException as Error;

    // Group all DB connection errors together
    if (err?.message?.includes('ECONNREFUSED') || err?.code === 'ETIMEDOUT') {
      event.fingerprint = ['database-connection-failure'];
    }

    // Group by error type + route, not message
    if (event.transaction) {
      event.fingerprint = [
        event.exception?.values?.[0]?.type || 'Error',
        event.transaction,
      ];
    }

    return event;
  },
});
```

---

## Performance Monitoring

```typescript
// Custom transaction for background jobs
const transaction = Sentry.startTransaction({
  op: 'queue.process',
  name: 'Process Email Queue',
});

try {
  Sentry.getCurrentHub().configureScope(scope => scope.setSpan(transaction));

  const span = transaction.startChild({ op: 'db.query', description: 'Fetch pending emails' });
  const emails = await db.getEmailQueue();
  span.finish();

  await sendEmails(emails);
  transaction.setStatus('ok');
} catch (err) {
  transaction.setStatus('internal_error');
  Sentry.captureException(err);
} finally {
  transaction.finish();
}
```

---

## Checklist

- [ ] `SENTRY_DSN` set in environment variables (never hardcoded)
- [ ] Sentry initialized before all other imports in entry file
- [ ] `beforeSend` hook scrubs passwords/tokens
- [ ] Error boundary wrapping React app root
- [ ] Sourcemaps uploaded and source map files deleted from public dist
- [ ] Release tracking in CI/CD pipeline with commit SHA
- [ ] User context set after authentication
- [ ] Performance `tracesSampleRate` tuned for production (0.05–0.1)

---

## References

- [Sentry Node.js docs](https://docs.sentry.io/platforms/javascript/guides/node/)
- [Sentry React docs](https://docs.sentry.io/platforms/javascript/guides/react/)
- [Sentry CLI releases](https://docs.sentry.io/cli/releases/)
- [Rollbar Node.js](https://docs.rollbar.com/docs/nodejs)

---

## User Interaction (MANDATORY)

After reading this skill, Claude MUST:

1. **Ask for platform**: Node.js API, React browser app, React Native mobile, or all?
2. **Ask for provider preference**: Sentry (recommended), Rollbar, or BugSnag?
3. **Ask about sourcemaps**: Using Vite, Webpack, or esbuild? Need automated upload in CI?
4. **Ask about performance monitoring**: Enable tracing and profiling as well?

Then generate complete SDK setup, error boundary, sourcemap upload config, and CI/CD release commands.
