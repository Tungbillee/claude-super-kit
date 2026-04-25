---
name: sk:nuxt-full-stack
description: "Nuxt 3 full-stack — routing, layouts, middleware, server routes, SSR/SSG/hybrid, deploy Vercel/Cloudflare"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: frontend
last_updated: 2026-04-25
license: MIT
---

# sk:nuxt-full-stack — Nuxt 3 Full-Stack Development

## When to Use

- Building Nuxt 3 pages, layouts, server routes
- Data fetching with useFetch/useAsyncData
- SSR / SSG / ISR / hybrid rendering strategies
- SEO with useSeoMeta
- Deploying to Vercel, Cloudflare Pages, Node server

## Project Structure

```
app/
├── components/          # Auto-imported
├── composables/         # Auto-imported (useXxx)
├── layouts/             # default.vue, auth.vue
├── middleware/          # Route middleware
├── pages/               # File-based routing
│   ├── index.vue
│   ├── blog/
│   │   ├── index.vue    # /blog
│   │   └── [slug].vue   # /blog/:slug (dynamic)
│   └── [...all].vue     # Catch-all
├── plugins/             # Vue plugins
└── utils/               # Auto-imported utilities
server/
├── api/                 # /api/* routes
├── middleware/          # Server middleware
├── routes/              # Non-/api server routes
└── utils/               # Server-only utilities
public/                  # Static assets
nuxt.config.ts
```

## File-Based Routing

```
pages/index.vue          → /
pages/about.vue          → /about
pages/blog/[slug].vue    → /blog/:slug    → useRoute().params.slug
pages/[...path].vue      → catch-all      → useRoute().params.path (array)
pages/[[optional]].vue   → optional param
```

## Data Fetching

```vue
<script setup lang="ts">
// useFetch — component-level, SSR-safe, auto-deduplicated
const { data: posts, status, error, refresh } = await useFetch('/api/posts', {
  query: { page: 1 },
  pick: ['id', 'title'],     // transform response
  transform: (r) => r.items, // alternative
  server: true,              // fetch on server (default)
  lazy: false,               // await before render (default)
  default: () => []          // fallback while loading
})

// useAsyncData — manual key control, multiple sources
const { data: user } = await useAsyncData('user', async () => {
  const [profile, stats] = await Promise.all([
    $fetch('/api/profile'),
    $fetch('/api/stats')
  ])
  return { profile, stats }
})

// $fetch — programmatic (no SSR dedup, use in actions)
async function submitForm(payload: FormData) {
  try {
    return await $fetch('/api/submit', { method: 'POST', body: payload })
  } catch (e) {
    throw createError({ statusCode: 400, message: 'Submit failed' })
  }
}
</script>
```

## Server Routes (Nitro)

```typescript
// server/api/posts/[id].get.ts
import { defineEventHandler, getRouterParam, createError } from 'h3'

export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')
  if (!id) throw createError({ statusCode: 400, message: 'Missing id' })

  const db = useDatabase() // server-only composable
  const post = await db.find(id)
  if (!post) throw createError({ statusCode: 404, message: 'Not found' })

  return post
})
```

```typescript
// server/api/posts/index.post.ts — POST handler
export default defineEventHandler(async (event) => {
  const body = await readValidatedBody(event, PostSchema.parse) // zod
  return createPost(body)
})
```

## Layouts

```vue
<!-- layouts/default.vue -->
<template>
  <div>
    <AppHeader />
    <main><slot /></main>
    <AppFooter />
  </div>
</template>
```

```vue
<!-- pages/dashboard.vue — use named layout -->
<script setup>
definePageMeta({ layout: 'dashboard' })
</script>
```

## Middleware

```typescript
// middleware/auth.ts — route middleware (client + server)
export default defineNuxtRouteMiddleware((to) => {
  const { is_authenticated } = useAuth()
  if (!is_authenticated.value) {
    return navigateTo(`/login?redirect=${to.fullPath}`)
  }
})
```

```vue
<script setup>
// Apply per-page
definePageMeta({ middleware: ['auth'] })
</script>
```

```typescript
// server/middleware/cors.ts — server-only middleware
export default defineEventHandler((event) => {
  setResponseHeaders(event, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE'
  })
})
```

## SEO with useSeoMeta

```vue
<script setup>
useSeoMeta({
  title: () => `${post.value?.title} | My Blog`,
  description: () => post.value?.excerpt,
  ogImage: () => post.value?.cover_url,
  twitterCard: 'summary_large_image'
})

// Or useHead for full control
useHead({
  link: [{ rel: 'canonical', href: canonical_url }]
})
</script>
```

## Rendering Modes

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  routeRules: {
    '/':            { prerender: true },          // SSG at build
    '/blog/**':     { isr: 60 },                  // ISR: revalidate 60s
    '/dashboard/**':{ ssr: false },               // SPA (client-only)
    '/api/**':      { cors: true, cache: false }  // API routes
  }
})
```

## Rendering Strategy Decision

| Page Type | Strategy | Rule |
|-----------|----------|------|
| Marketing / landing | `prerender: true` | Static, fast CDN |
| Blog posts | `isr: 60` | Fresh content, CDN cache |
| User dashboard | `ssr: false` | Auth-gated, SPA |
| Product pages | `isr: 300` | Catalog, infrequent updates |
| Real-time | `ssr: true` | Always fresh |

## Deploy Config

```typescript
// Vercel (zero-config with @nuxt/vercel preset)
export default defineNuxtConfig({
  nitro: { preset: 'vercel' }
})

// Cloudflare Pages
export default defineNuxtConfig({
  nitro: { preset: 'cloudflare-pages' }
})

// Node server
export default defineNuxtConfig({
  nitro: { preset: 'node-server' }
})
```

## Auto-Imports Cheatsheet

| What | Where |
|------|-------|
| Vue composables | `composables/*.ts` → `useXxx` |
| Utilities | `utils/*.ts` → all exports |
| Components | `components/**/*.vue` → auto-named |
| Server utils | `server/utils/*.ts` → server-only |

## Common nuxt.config.ts

```typescript
export default defineNuxtConfig({
  devtools: { enabled: true },
  typescript: { strict: true },
  modules: ['@pinia/nuxt', '@nuxtjs/tailwindcss', '@vueuse/nuxt'],
  runtimeConfig: {
    db_url: '',          // server-only (process.env.DB_URL)
    public: {
      api_base: ''       // exposed to client
    }
  }
})
```

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What Nuxt task to help with?",
      header: "Task",
      options: [
        { label: "Page / routing", description: "File-based routing, params" },
        { label: "Data fetching", description: "useFetch / useAsyncData" },
        { label: "Server route", description: "API endpoint with Nitro" },
        { label: "Deploy config", description: "Vercel / Cloudflare / Node" }
      ]
    },
    {
      question: "Rendering strategy?",
      header: "Rendering",
      options: [
        { label: "SSR (default)", description: "Server-rendered each request" },
        { label: "SSG / prerender", description: "Static at build time" },
        { label: "ISR", description: "Static + revalidate interval" },
        { label: "SPA (client-only)", description: "Auth-gated pages" }
      ]
    }
  ]
})
```
