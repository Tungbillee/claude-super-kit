---
name: sk:api-versioning
description: API versioning strategies - URI (/v1/), header versioning, query param versioning, semantic versioning for APIs, deprecation with Sunset header, backwards compatibility patterns.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: api
argument-hint: "[versioning strategy or deprecation task]"
---

# sk:api-versioning

Complete guide for versioning REST APIs — from choosing a strategy to managing deprecation gracefully.

## When to Use

- Designing a new API that needs versioning from day one
- Adding breaking changes to an existing API
- Setting up deprecation notices and migration timelines
- Implementing backwards-compatible API changes
- Documenting version lifecycle for API consumers
- Choosing between URI, header, or query param versioning

---

## 1. Versioning Strategies Comparison

| Strategy | Example | Pros | Cons |
|---|---|---|---|
| URI path | `/v1/users` | Visible, cacheable, easy to test | URL pollution, not REST-pure |
| Header | `API-Version: 2` | Clean URLs, REST-pure | Harder to test in browser |
| Query param | `/users?version=2` | No URL changes | Easily missed, cache issues |
| Content negotiation | `Accept: application/vnd.api+json;version=2` | Very REST-pure | Most complex |

**Recommendation:** URI path versioning (`/v1/`) for most REST APIs — best developer experience and cacheability.

---

## 2. URI Path Versioning

### Express.js Implementation

```typescript
// src/routes/index.ts
import { Router } from 'express';
import { v1Router } from './v1';
import { v2Router } from './v2';

const router = Router();

router.use('/v1', v1Router);
router.use('/v2', v2Router);

// Alias latest version
router.use('/latest', v2Router);

export default router;
```

```typescript
// src/routes/v1/users.ts
import { Router } from 'express';

const router = Router();

// V1: returns flat user object
router.get('/users/:id', async (req, res) => {
  const user = await findUser(req.params.id);
  res.json({
    id: user.id,
    name: user.name,
    email: user.email,
  });
});

export const v1UsersRouter = router;
```

```typescript
// src/routes/v2/users.ts
// V2: returns nested structure + new fields
router.get('/users/:id', async (req, res) => {
  const user = await findUser(req.params.id);
  res.json({
    id: user.id,
    profile: {
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url,
    },
    metadata: {
      created_at: user.created_at,
      updated_at: user.updated_at,
    },
  });
});
```

### Next.js App Router

```
app/
└── api/
    ├── v1/
    │   └── users/
    │       ├── route.ts
    │       └── [id]/route.ts
    └── v2/
        └── users/
            ├── route.ts
            └── [id]/route.ts
```

```typescript
// app/api/v2/users/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const user = await findUser(params.id);
  if (!user) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  return NextResponse.json({ id: user.id, profile: { name: user.name } });
}
```

---

## 3. Header Versioning

```typescript
// middleware/version-router.ts
import { Request, Response, NextFunction } from 'express';

export function versionRouter(req: Request, res: Response, next: NextFunction) {
  const version = req.headers['api-version'] as string
    ?? req.headers['accept']?.match(/version=(\d+)/)?.[1]
    ?? '1';

  req.apiVersion = parseInt(version, 10);
  next();
}

// Route handler uses version
app.get('/users/:id', versionMiddleware, async (req, res) => {
  const user = await findUser(req.params.id);

  if (req.apiVersion >= 2) {
    return res.json({ id: user.id, profile: { name: user.name } });
  }
  // V1 response
  return res.json({ id: user.id, name: user.name });
});
```

```typescript
// Extend Express Request type
declare global {
  namespace Express {
    interface Request {
      apiVersion: number;
    }
  }
}
```

---

## 4. Semantic Versioning for APIs

```
API Version: MAJOR.MINOR.PATCH

MAJOR — breaking changes (increment URI version: /v1/ → /v2/)
MINOR — new backwards-compatible features (add optional fields)
PATCH — bug fixes, no behavior change

Breaking changes (require MAJOR bump):
  ✗ Removing a field from response
  ✗ Renaming a field
  ✗ Changing field type (string → number)
  ✗ Removing an endpoint
  ✗ Changing required request parameters
  ✗ Changing authentication requirements
  ✗ Changing error response format

Non-breaking changes (MINOR or PATCH):
  ✓ Adding new optional fields to response
  ✓ Adding new optional request parameters
  ✓ Adding new endpoints
  ✓ Expanding enum values (with care)
  ✓ Bug fixes that don't change documented behavior
```

---

## 5. Deprecation Strategy (Sunset Header)

```typescript
// middleware/deprecation.ts
import { Request, Response, NextFunction } from 'express';

interface DeprecationConfig {
  sunset_date: string;      // ISO date when endpoint removed
  replacement_url?: string;
  message?: string;
}

export function deprecate(config: DeprecationConfig) {
  return (req: Request, res: Response, next: NextFunction) => {
    // RFC 8594 Sunset header
    res.setHeader('Sunset', new Date(config.sunset_date).toUTCString());

    // Deprecation header (draft RFC)
    res.setHeader('Deprecation', 'true');

    if (config.replacement_url) {
      res.setHeader('Link', `<${config.replacement_url}>; rel="successor-version"`);
    }

    // Warning header (informational)
    res.setHeader(
      'Warning',
      `299 - "This API version is deprecated. ${config.message ?? ''} Please migrate to ${config.replacement_url ?? 'the latest version'} before ${config.sunset_date}."`
    );

    next();
  };
}
```

```typescript
// Apply to V1 routes
v1Router.use(
  '/users',
  deprecate({
    sunset_date: '2027-01-01',
    replacement_url: 'https://api.example.com/v2/users',
    message: 'V1 will be sunset on 2027-01-01.',
  }),
  v1UsersRouter
);
```

### Deprecation Timeline Example

```
2026-04-25  V2 released
2026-05-01  V1 marked deprecated (Sunset + Deprecation headers added)
2026-06-01  Email notifications sent to API consumers
2026-09-01  Warning period begins (400 responses on V1 with migration info)
2027-01-01  V1 removed (410 Gone)
```

---

## 6. Backwards Compatibility Patterns

### Additive Changes Only

```typescript
// V2 response — adds new fields, keeps old ones for compatibility
interface UserV2 {
  id: string;
  name: string;          // kept from V1
  email: string;         // kept from V1
  // New in V2:
  avatar_url?: string;   // optional, no break for V1 clients
  role?: 'admin' | 'user';
}
```

### Field Aliasing (rename without breaking)

```typescript
// Transition period: support both old and new field names
router.get('/users/:id', async (req, res) => {
  const user = await findUser(req.params.id);
  res.json({
    // New name
    full_name: user.full_name,
    // Old name (deprecated, kept for backwards compat)
    name: user.full_name,   // alias
  });
});
```

### Request Normalization

```typescript
// Accept both V1 and V2 request formats
function normalizeCreateUserRequest(body: any): CreateUserInput {
  // V2 format: { profile: { name, email } }
  if (body.profile) {
    return { name: body.profile.name, email: body.profile.email };
  }
  // V1 format: { name, email }
  return { name: body.name, email: body.email };
}
```

---

## 7. API Version Documentation

```yaml
# openapi.yaml — document multiple versions
openapi: "3.1.0"
info:
  title: My API
  version: "2.0.0"
  x-api-version-lifecycle:
    current: "v2"
    supported: ["v1", "v2"]
    deprecated: ["v1"]
    sunset:
      v1: "2027-01-01"

servers:
  - url: https://api.example.com/v2
    description: Current version
  - url: https://api.example.com/v1
    description: Deprecated (sunset 2027-01-01)
```

---

## 8. Version Detection Middleware (All Strategies)

```typescript
// middleware/detect-api-version.ts
export function detectApiVersion(req: Request, res: Response, next: NextFunction) {
  // 1. URI path version (highest priority)
  const uri_match = req.path.match(/^\/v(\d+)\//);
  if (uri_match) {
    req.apiVersion = parseInt(uri_match[1], 10);
    return next();
  }

  // 2. Header version
  const header_version = req.headers['api-version'];
  if (header_version) {
    req.apiVersion = parseInt(header_version as string, 10);
    return next();
  }

  // 3. Query param version
  const query_version = req.query.version;
  if (query_version) {
    req.apiVersion = parseInt(query_version as string, 10);
    return next();
  }

  // 4. Default to latest
  req.apiVersion = LATEST_API_VERSION;
  next();
}
```

---

## Reference Docs

- [RFC 8594 — Sunset Header](https://datatracker.ietf.org/doc/html/rfc8594)
- [Stripe API Versioning](https://stripe.com/docs/api/versioning)
- [GitHub REST API Versioning](https://docs.github.com/en/rest/overview/api-versions)
- [OpenAPI Versioning](https://swagger.io/blog/api-strategy/api-versioning/)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md#api-versioning)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn đang dùng framework nào? (Express / Fastify / Next.js / NestJS / other)"
2. "Versioning strategy ưa thích: URI path (/v1/) / header / query param?"
3. "Bạn cần: setup versioning mới / thêm deprecation notices / handle breaking changes / migration strategy?"
4. "Đây là internal API hay public API với external consumers?"

Cung cấp implementation cụ thể và deprecation timeline phù hợp với context của họ.
