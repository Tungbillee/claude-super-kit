---
name: sk:astro-static
description: Astro islands architecture, content collections, integrations (React/Vue/Svelte), partial hydration (client:load/visible/idle), SSR vs SSG, deployment. Zero-JS by default static sites.
license: MIT
argument-hint: "[islands|content|integration|hydration|deploy] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: frontend
  last_updated: "2026-04-25"
---

# Astro Static Site Skill

Astro for content-focused sites with islands architecture - ship less JavaScript.

## When to Use

- Building marketing sites, blogs, documentation
- Multi-framework component islands (React + Svelte together)
- Content-heavy sites with content collections
- Zero-JS by default with selective hydration
- Portfolio, docs, e-commerce landing pages

## Project Structure

```
src/
├── components/           # .astro, .tsx, .svelte etc
├── layouts/              # Layout components
│   └── Base.astro
├── pages/                # File-based routing
│   ├── index.astro       # /
│   ├── blog/
│   │   ├── index.astro   # /blog
│   │   └── [slug].astro  # /blog/[slug]
│   └── api/
│       └── search.ts     # /api/search endpoint
├── content/              # Content collections
│   ├── config.ts
│   └── blog/
│       ├── post-1.md
│       └── post-2.mdx
└── styles/
    └── global.css
```

## Astro Components

```astro
---
// src/components/Card.astro - frontmatter (server-only)
import type { CollectionEntry } from 'astro:content';

interface Props {
  post: CollectionEntry<'blog'>;
  featured?: boolean;
}

const { post, featured = false } = Astro.props;
const { title, description, pubDate } = post.data;
const formatted_date = pubDate.toLocaleDateString('vi-VN');
---

<!-- Template - static HTML -->
<article class:list={['card', { featured }]}>
  <h2>{title}</h2>
  <time datetime={pubDate.toISOString()}>{formatted_date}</time>
  <p>{description}</p>
  <a href={`/blog/${post.slug}`}>Read more →</a>
</article>

<style>
  /* Scoped by default */
  .card { padding: 1rem; border: 1px solid #eee; }
  .featured { border-color: blue; }
</style>
```

## Content Collections

```typescript
// src/content/config.ts
import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  type: 'content', // .md/.mdx
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
    image: z.object({ src: z.string(), alt: z.string() }).optional(),
  }),
});

const docs = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    order: z.number(),
  }),
});

export const collections = { blog, docs };
```

```astro
---
// src/pages/blog/[slug].astro
import { getCollection, getEntry } from 'astro:content';
import Layout from '../../layouts/Base.astro';

export async function getStaticPaths() {
  const posts = await getCollection('blog', ({ data }) => !data.draft);
  return posts.map(post => ({
    params: { slug: post.slug },
    props: { post },
  }));
}

const { post } = Astro.props;
const { Content } = await post.render();
---

<Layout title={post.data.title}>
  <article>
    <h1>{post.data.title}</h1>
    <Content />
  </article>
</Layout>
```

## Islands Architecture & Hydration

```astro
---
// src/pages/index.astro
import StaticHeader from '../components/Header.astro';   // 0 JS
import ReactCounter from '../components/Counter.tsx';    // hydrated
import SvelteSearch from '../components/Search.svelte';  // hydrated
---

<!-- No client JS - pure static HTML -->
<StaticHeader />

<!-- client:load - hydrate immediately on page load -->
<ReactCounter client:load initialCount={0} />

<!-- client:visible - hydrate when scrolled into view (IntersectionObserver) -->
<SvelteSearch client:visible />

<!-- client:idle - hydrate when browser is idle (requestIdleCallback) -->
<HeavyWidget client:idle />

<!-- client:media - hydrate on media query match -->
<MobileMenu client:media="(max-width: 768px)" />

<!-- client:only - skip SSR, render only on client -->
<MapComponent client:only="react" />
```

## Integrations

```javascript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import svelte from '@astrojs/svelte';
import vue from '@astrojs/vue';
import tailwind from '@astrojs/tailwind';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://mysite.com',
  integrations: [
    react(),
    svelte(),
    vue(),
    tailwind(),
    mdx({
      remarkPlugins: [remarkToc],
      rehypePlugins: [rehypeHighlight],
    }),
    sitemap(),
  ],
  // SSR mode
  output: 'server', // 'static' (default) | 'server' | 'hybrid'
  adapter: vercel(), // needed for output: 'server'
});
```

## SSR (Server Mode)

```astro
---
// src/pages/dashboard.astro
// output: 'server' or export const prerender = false (hybrid)
import { getSession } from '../lib/auth';

const session = await getSession(Astro.request);
if (!session) return Astro.redirect('/login');

const user = await db.user.findUnique({ where: { id: session.user_id } });
---
<h1>Dashboard for {user?.name}</h1>
```

```typescript
// src/pages/api/contact.ts - API endpoint
import type { APIRoute } from 'astro';

export const POST: APIRoute = async ({ request }) => {
  const body = await request.json();

  if (!body.email) {
    return new Response(JSON.stringify({ error: 'Email required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  await sendEmail(body);
  return new Response(JSON.stringify({ success: true }));
};
```

## Layouts with Slots

```astro
---
// src/layouts/Base.astro
interface Props {
  title: string;
  description?: string;
}
const { title, description = 'My site' } = Astro.props;
---
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8" />
  <title>{title}</title>
  <meta name="description" content={description} />
</head>
<body>
  <slot name="header" />  <!-- named slot -->
  <main>
    <slot />              <!-- default slot -->
  </main>
  <slot name="footer" />
</body>
</html>
```

## SSG vs SSR Decision

| Use Case | Mode |
|----------|------|
| Blog, docs, marketing | `static` (default) |
| Dashboard with auth | `server` |
| Mostly static + few dynamic | `hybrid` |
| E-commerce product pages | `hybrid` (SSG products, SSR cart) |

## Resources

- Astro docs: https://docs.astro.build
- Integrations: https://astro.build/integrations
- Themes: https://astro.build/themes

## User Interaction (MANDATORY)

When activated, ask:

1. **Project type:** "Loại site bạn đang xây? (blog/docs/marketing/e-commerce/portfolio)"
2. **Interactivity needs:** "Phần nào cần JavaScript? (search/forms/charts/auth)"
3. **Preferred UI framework:** "Bạn thích React, Svelte hay Vue cho islands?"

Then provide Astro setup with right hydration strategy.
