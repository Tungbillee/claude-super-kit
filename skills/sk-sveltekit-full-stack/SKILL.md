---
name: sk:sveltekit-full-stack
description: SvelteKit SSR/SSG, file-based routing, +page.server.ts, load functions, form actions, hooks (handle/handleError), API endpoints, adapters (Vercel/Node/Cloudflare). Full-stack Svelte apps.
license: MIT
argument-hint: "[routing|load|forms|hooks|api|deploy] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: frontend
  last_updated: "2026-04-25"
---

# SvelteKit Full-Stack Skill

SvelteKit for full-stack applications with SSR, SSG, and server-side logic.

## When to Use

- Building full-stack apps with SvelteKit
- Setting up file-based routing with layouts
- Writing server-side load functions and form actions
- Creating API endpoints (+server.ts)
- Configuring hooks for auth, error handling
- Deploying to Vercel, Node, or Cloudflare

## File Routing

```
src/routes/
├── +layout.svelte          # Root layout (persistent)
├── +layout.server.ts       # Root layout server load
├── +page.svelte            # Home page (/)
├── +page.server.ts         # Home server load/actions
├── blog/
│   ├── +page.svelte        # /blog
│   ├── +page.server.ts
│   └── [slug]/
│       ├── +page.svelte    # /blog/[slug]
│       └── +page.server.ts
├── api/
│   └── users/
│       └── +server.ts      # /api/users REST endpoint
└── (auth)/                 # Route group (no URL segment)
    ├── login/+page.svelte
    └── register/+page.svelte
```

## Load Functions

```typescript
// +page.server.ts - runs on server only
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ params, fetch, locals, cookies }) => {
  const post = await db.post.findUnique({ where: { slug: params.slug } });

  if (!post) throw error(404, 'Post not found');

  return { post }; // available as data.post in page
};
```

```typescript
// +page.ts - runs on server + client (universal load)
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, data, params }) => {
  // data = from +page.server.ts (if exists)
  const extra = await fetch(`/api/related/${params.slug}`).then(r => r.json());
  return { ...data, extra };
};
```

```svelte
<!-- +page.svelte -->
<script lang="ts">
  import type { PageData } from './$types';
  let { data } = $props(); // typed PageData
</script>
<h1>{data.post.title}</h1>
```

## Form Actions

```typescript
// +page.server.ts
import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';

export const actions: Actions = {
  // Default action
  default: async ({ request, cookies }) => {
    const form_data = await request.formData();
    const email = form_data.get('email') as string;
    const password = form_data.get('password') as string;

    if (!email || !password) {
      return fail(400, { email, error: 'All fields required' });
    }

    const user = await auth.login(email, password);
    if (!user) return fail(401, { email, error: 'Invalid credentials' });

    cookies.set('session', user.session_token, { path: '/', httpOnly: true });
    throw redirect(303, '/dashboard');
  },

  // Named actions - /login?/logout
  logout: async ({ cookies }) => {
    cookies.delete('session', { path: '/' });
    throw redirect(303, '/login');
  }
};
```

```svelte
<!-- +page.svelte with progressive enhancement -->
<script lang="ts">
  import { enhance } from '$app/forms';
  import type { ActionData } from './$types';

  let { form } = $props<{ form: ActionData }>();
</script>

<form method="POST" use:enhance>
  <input name="email" value={form?.email ?? ''} />
  {#if form?.error}<p class="error">{form.error}</p>{/if}
  <button>Login</button>
</form>
```

## API Endpoints

```typescript
// src/routes/api/users/+server.ts
import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, locals }) => {
  if (!locals.user) throw error(401, 'Unauthorized');

  const page = Number(url.searchParams.get('page') ?? 1);
  const users = await db.user.findMany({ skip: (page - 1) * 20, take: 20 });

  return json({ users, page });
};

export const POST: RequestHandler = async ({ request, locals }) => {
  const body = await request.json();
  // validate...
  const user = await db.user.create({ data: body });
  return json(user, { status: 201 });
};
```

## Hooks

```typescript
// src/hooks.server.ts
import type { Handle, HandleServerError } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  // Auth middleware
  const session_token = event.cookies.get('session');
  if (session_token) {
    event.locals.user = await auth.validateSession(session_token);
  }

  // Add response headers
  const response = await resolve(event, {
    transformPageChunk: ({ html }) => html.replace('%lang%', 'vi')
  });

  response.headers.set('X-Frame-Options', 'SAMEORIGIN');
  return response;
};

export const handleError: HandleServerError = async ({ error, event }) => {
  console.error('Server error:', error, event.url.pathname);
  return { message: 'Internal error', code: 'INTERNAL' };
};
```

## Layouts & Protected Routes

```typescript
// src/routes/(protected)/+layout.server.ts
import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals }) => {
  if (!locals.user) throw redirect(303, '/login');
  return { user: locals.user };
};
```

```typescript
// src/app.d.ts - extend locals type
declare global {
  namespace App {
    interface Locals {
      user: { id: string; email: string; role: string } | null;
    }
    interface PageData {
      user?: App.Locals['user'];
    }
  }
}
```

## SSR vs SSG Configuration

```typescript
// +page.server.ts or +layout.server.ts
export const prerender = true;  // SSG - pre-render at build
export const ssr = false;       // CSR only (SPA mode)
export const csr = false;       // No client JS (pure SSR)

// Dynamic segments with prerender
export function entries() {
  return [{ slug: 'hello' }, { slug: 'world' }];
}
export const prerender = true;
```

## Adapters

```javascript
// svelte.config.js - Vercel
import adapter from '@sveltejs/adapter-vercel';
export default { kit: { adapter: adapter({ runtime: 'nodejs20.x' }) } };

// Node.js server
import adapter from '@sveltejs/adapter-node';
export default { kit: { adapter: adapter({ out: 'build' }) } };

// Cloudflare Pages
import adapter from '@sveltejs/adapter-cloudflare';
export default { kit: { adapter: adapter() } };

// Auto (detects platform)
import adapter from '@sveltejs/adapter-auto';
```

## $app Modules

```typescript
import { page } from '$app/stores';         // current page data
import { navigating } from '$app/stores';    // navigation state
import { goto, preloadData } from '$app/navigation';
import { browser, dev, building } from '$app/environment';
import { PUBLIC_API_URL } from '$env/static/public'; // .env vars
import { DATABASE_URL } from '$env/static/private';  // server-only
```

## Resources

- SvelteKit docs: https://kit.svelte.dev/docs
- Adapters: https://kit.svelte.dev/docs/adapters
- Form actions: https://kit.svelte.dev/docs/form-actions

## User Interaction (MANDATORY)

When activated, ask:

1. **Task:** "Bạn cần làm gì? (routing/load/forms/hooks/api/deploy)"
2. **Auth setup:** "App có authentication chưa? Dùng gì? (session/JWT/OAuth)"
3. **Deployment target:** "Deploy lên đâu? (Vercel/Node/Cloudflare/Static)"

Then provide targeted SvelteKit implementation with TypeScript types.
