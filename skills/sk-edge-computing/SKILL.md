---
name: sk:edge-computing
description: Edge computing deployment - Vercel Edge Functions (Edge Runtime), Cloudflare Workers (KV/R2/D1), Netlify Edge Functions. Decision framework, common patterns (auth, A/B testing, geo-routing).
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: devops
argument-hint: "[edge platform or use case pattern]"
---

# sk:edge-computing

Complete guide for building and deploying edge functions across Vercel, Cloudflare, and Netlify.

## When to Use

- Reducing latency with code running closest to users
- Implementing auth/middleware without hitting origin servers
- A/B testing and feature flags at the edge
- Geo-based routing, redirects, and personalization
- Rate limiting and bot protection at edge
- Choosing between Vercel Edge, Cloudflare Workers, and Netlify Edge

---

## 1. Platform Comparison

| Feature | Vercel Edge | Cloudflare Workers | Netlify Edge |
|---|---|---|---|
| Runtime | Edge Runtime (V8) | V8 isolates | Deno |
| Cold start | ~0ms | ~0ms | ~0ms |
| Locations | Vercel network | 300+ PoPs | Netlify CDN |
| Storage | None built-in | KV, R2, D1 | None built-in |
| Max CPU time | 25s wall, 2s CPU | 50ms (free) / 30s (paid) | No stated limit |
| Max memory | 128MB | 128MB | 512MB |
| Node.js compat | Partial (Edge Runtime) | Via compat flag | Full (Deno) |
| Best for | Next.js middleware | Storage needs, complex logic | Netlify projects |

---

## 2. Vercel Edge Functions

### Middleware (runs on every request)

```typescript
// middleware.ts (root of Next.js project)
import { NextRequest, NextResponse } from 'next/server';

export const config = {
  matcher: [
    // Apply to all routes except static files
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|gif|webp)).*)',
  ],
};

export function middleware(request: NextRequest): NextResponse {
  const response = NextResponse.next();

  // Add security headers
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');

  return response;
}
```

### Auth at Edge

```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from 'jose';

const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET!);

export async function middleware(request: NextRequest): Promise<NextResponse> {
  const { pathname } = request.nextUrl;

  // Public routes
  if (pathname.startsWith('/api/auth') || pathname === '/login') {
    return NextResponse.next();
  }

  // Protected routes
  if (pathname.startsWith('/dashboard') || pathname.startsWith('/api/')) {
    const token = request.cookies.get('auth-token')?.value
      ?? request.headers.get('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return pathname.startsWith('/api/')
        ? NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
        : NextResponse.redirect(new URL('/login', request.url));
    }

    try {
      const { payload } = await jwtVerify(token, JWT_SECRET);
      const response = NextResponse.next();
      response.headers.set('x-user-id', payload.sub as string);
      response.headers.set('x-user-role', payload.role as string);
      return response;
    } catch {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  return NextResponse.next();
}
```

### A/B Testing at Edge

```typescript
// middleware.ts
export function middleware(request: NextRequest): NextResponse {
  const bucket = request.cookies.get('ab-bucket')?.value;
  const response = NextResponse.next();

  if (!bucket) {
    // Assign user to bucket deterministically by IP
    const ip = request.ip ?? request.headers.get('x-forwarded-for') ?? 'unknown';
    const hash = simpleHash(ip);
    const assigned_bucket = hash % 2 === 0 ? 'control' : 'variant';

    response.cookies.set('ab-bucket', assigned_bucket, {
      maxAge: 60 * 60 * 24 * 30, // 30 days
      httpOnly: true,
    });
    response.headers.set('x-ab-bucket', assigned_bucket);
  } else {
    response.headers.set('x-ab-bucket', bucket);
  }

  return response;
}

function simpleHash(str: string): number {
  return str.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0);
}
```

### Geo-Routing

```typescript
export function middleware(request: NextRequest): NextResponse {
  const country = request.geo?.country ?? 'US';
  const city = request.geo?.city;

  // Redirect Vietnamese users to Vietnamese subdomain
  if (country === 'VN' && !request.nextUrl.hostname.startsWith('vi.')) {
    const url = request.nextUrl.clone();
    url.hostname = `vi.${url.hostname}`;
    return NextResponse.redirect(url);
  }

  // Add geo headers for downstream use
  const response = NextResponse.next();
  response.headers.set('x-user-country', country);
  if (city) response.headers.set('x-user-city', city);
  return response;
}
```

---

## 3. Cloudflare Workers

```bash
npm install -g wrangler
wrangler init my-worker
```

```toml
# wrangler.toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2026-04-25"
compatibility_flags = ["nodejs_compat"]

[vars]
ENVIRONMENT = "production"

[[kv_namespaces]]
binding = "CACHE"
id = "xxx"

[[r2_buckets]]
binding = "STORAGE"
bucket_name = "my-bucket"

[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "xxx"
```

### Worker Handler

```typescript
// src/index.ts
export interface Env {
  CACHE: KVNamespace;
  STORAGE: R2Bucket;
  DB: D1Database;
  JWT_SECRET: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    try {
      if (url.pathname === '/api/users') return handleUsers(request, env);
      if (url.pathname.startsWith('/api/files/')) return handleFiles(request, env);
      return new Response('Not Found', { status: 404 });
    } catch (error) {
      return new Response('Internal Server Error', { status: 500 });
    }
  },
};
```

### KV (Key-Value Store)

```typescript
// Cache with TTL
async function getCachedData(env: Env, key: string): Promise<unknown | null> {
  const cached = await env.CACHE.get(key, { type: 'json' });
  return cached;
}

async function setCachedData(env: Env, key: string, data: unknown, ttl_seconds = 300): Promise<void> {
  await env.CACHE.put(key, JSON.stringify(data), { expirationTtl: ttl_seconds });
}

// Usage: cache expensive API calls
async function handleUsers(request: Request, env: Env): Promise<Response> {
  const cache_key = 'users:list';
  const cached = await getCachedData(env, cache_key);
  if (cached) return Response.json(cached);

  const users = await fetchUsersFromOrigin();
  await setCachedData(env, cache_key, users, 60); // 1 min TTL
  return Response.json(users);
}
```

### R2 (Object Storage — S3-compatible)

```typescript
async function handleFiles(request: Request, env: Env): Promise<Response> {
  const key = new URL(request.url).pathname.replace('/api/files/', '');

  if (request.method === 'GET') {
    const object = await env.STORAGE.get(key);
    if (!object) return new Response('Not Found', { status: 404 });

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    return new Response(object.body, { headers });
  }

  if (request.method === 'PUT') {
    await env.STORAGE.put(key, request.body, {
      httpMetadata: { contentType: request.headers.get('Content-Type') ?? 'application/octet-stream' },
    });
    return Response.json({ success: true, key });
  }

  return new Response('Method Not Allowed', { status: 405 });
}
```

### D1 (SQLite at Edge)

```typescript
async function queryUsers(env: Env): Promise<unknown[]> {
  const { results } = await env.DB.prepare(
    'SELECT id, name, email FROM users WHERE active = ? ORDER BY created_at DESC LIMIT 100'
  )
    .bind(1)
    .all();
  return results;
}

async function createUser(env: Env, name: string, email: string): Promise<void> {
  await env.DB.prepare('INSERT INTO users (name, email, active) VALUES (?, ?, 1)')
    .bind(name, email)
    .run();
}
```

### Rate Limiting (Cloudflare Workers)

```typescript
// Using KV for distributed rate limiting
async function checkRateLimit(
  env: Env,
  client_ip: string,
  limit = 100,
  window_seconds = 60
): Promise<{ allowed: boolean; remaining: number }> {
  const key = `rate:${client_ip}:${Math.floor(Date.now() / (window_seconds * 1000))}`;
  const current = parseInt((await env.CACHE.get(key)) ?? '0', 10);

  if (current >= limit) return { allowed: false, remaining: 0 };

  await env.CACHE.put(key, String(current + 1), { expirationTtl: window_seconds });
  return { allowed: true, remaining: limit - current - 1 };
}
```

### Deploy

```bash
wrangler dev          # local dev
wrangler deploy       # production
wrangler tail         # live logs
wrangler kv key list --binding=CACHE
```

---

## 4. Netlify Edge Functions

```typescript
// netlify/edge-functions/auth.ts
import type { Config, Context } from '@netlify/edge-functions';

export default async function handler(request: Request, context: Context): Promise<Response> {
  const token = request.headers.get('Authorization')?.replace('Bearer ', '');

  if (!token) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Verify token (Deno-compatible JWT)
  try {
    const payload = await verifyToken(token);
    // Pass user info to origin via headers
    const req_with_user = new Request(request, {
      headers: { ...Object.fromEntries(request.headers), 'x-user-id': payload.sub },
    });
    return context.next(req_with_user);
  } catch {
    return new Response('Invalid token', { status: 401 });
  }
}

export const config: Config = {
  path: '/api/*',
  excludedPath: '/api/auth/*',
};
```

---

## 5. Choosing the Right Platform

```
Use Vercel Edge if:
  ✓ Already using Next.js or Vercel hosting
  ✓ Need middleware (auth, redirects, headers)
  ✓ Simple request transformation

Use Cloudflare Workers if:
  ✓ Need edge storage (KV cache, R2 files, D1 database)
  ✓ Complex business logic at edge
  ✓ Rate limiting, bot protection
  ✓ Global low-latency API (300+ PoPs)
  ✓ Not tied to a specific hosting platform

Use Netlify Edge if:
  ✓ Already using Netlify hosting
  ✓ Prefer Deno runtime (better Node.js compat)
  ✓ Simple auth/personalization patterns
```

---

## Reference Docs

- [Vercel Edge Middleware](https://nextjs.org/docs/app/building-your-application/routing/middleware)
- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Cloudflare KV](https://developers.cloudflare.com/kv/)
- [Cloudflare R2](https://developers.cloudflare.com/r2/)
- [Cloudflare D1](https://developers.cloudflare.com/d1/)
- [Netlify Edge Functions](https://docs.netlify.com/edge-functions/overview/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn đang dùng hosting platform nào? (Vercel / Cloudflare / Netlify / chưa chọn)"
2. "Use case: auth middleware / A/B testing / geo-routing / rate limiting / edge caching / edge API?"
3. "Bạn có cần lưu data ở edge không? (session cache / file storage / SQL query)"
4. "Framework hiện tại: Next.js / SvelteKit / Astro / vanilla?"

Cung cấp implementation code và config deploy sẵn sàng sử dụng cho platform của họ.
