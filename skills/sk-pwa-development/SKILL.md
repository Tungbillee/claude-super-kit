---
name: sk:pwa-development
description: Progressive Web App development - Service Workers (lifecycle, caching strategies), Web Manifest, Push Notifications (Push API), offline-first patterns, Workbox library integration.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: web
argument-hint: "[PWA feature or caching strategy]"
---

# sk:pwa-development

Complete guide for building Production-Ready Progressive Web Apps with offline support, installability, and push notifications.

## When to Use

- Adding offline support to a web application
- Implementing background sync and push notifications
- Making a web app installable (Add to Home Screen)
- Choosing the right caching strategy per resource type
- Using Workbox to simplify service worker complexity
- Auditing PWA score (Lighthouse PWA checklist)

---

## 1. Web App Manifest

```json
// public/manifest.json
{
  "name": "My PWA App",
  "short_name": "MyApp",
  "description": "A progressive web application",
  "start_url": "/?utm_source=pwa",
  "display": "standalone",
  "orientation": "portrait-primary",
  "background_color": "#ffffff",
  "theme_color": "#1a73e8",
  "icons": [
    { "src": "/icons/icon-72x72.png",   "sizes": "72x72",   "type": "image/png" },
    { "src": "/icons/icon-192x192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "/icons/icon-512x512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ],
  "screenshots": [
    { "src": "/screenshots/mobile.png", "sizes": "390x844", "type": "image/png", "form_factor": "narrow" },
    { "src": "/screenshots/desktop.png", "sizes": "1280x720", "type": "image/png", "form_factor": "wide" }
  ],
  "categories": ["productivity", "utilities"],
  "shortcuts": [
    {
      "name": "New Document",
      "url": "/new",
      "icons": [{ "src": "/icons/new-doc.png", "sizes": "96x96" }]
    }
  ]
}
```

```html
<!-- index.html -->
<link rel="manifest" href="/manifest.json" />
<meta name="theme-color" content="#1a73e8" />
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
<link rel="apple-touch-icon" href="/icons/icon-192x192.png" />
```

---

## 2. Service Worker Lifecycle

```typescript
// public/sw.ts (compiled to sw.js)
const CACHE_VERSION = 'v1.2.0';
const STATIC_CACHE = `static-${CACHE_VERSION}`;
const DYNAMIC_CACHE = `dynamic-${CACHE_VERSION}`;

const PRECACHE_ASSETS = [
  '/',
  '/offline.html',
  '/css/app.css',
  '/js/app.js',
];

// Install — precache static assets
self.addEventListener('install', (event: ExtendableEvent) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(PRECACHE_ASSETS))
  );
  (self as ServiceWorkerGlobalScope).skipWaiting();
});

// Activate — clean up old caches
self.addEventListener('activate', (event: ExtendableEvent) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== STATIC_CACHE && key !== DYNAMIC_CACHE)
          .map((key) => caches.delete(key))
      )
    )
  );
  (self as ServiceWorkerGlobalScope).clients.claim();
});
```

### Register Service Worker

```typescript
// src/registerSW.ts
export async function registerServiceWorker(): Promise<void> {
  if (!('serviceWorker' in navigator)) return;

  try {
    const registration = await navigator.serviceWorker.register('/sw.js', {
      scope: '/',
      updateViaCache: 'none',
    });

    registration.addEventListener('updatefound', () => {
      const new_worker = registration.installing;
      new_worker?.addEventListener('statechange', () => {
        if (new_worker.state === 'installed' && navigator.serviceWorker.controller) {
          // New version available — notify user
          showUpdatePrompt(() => {
            new_worker.postMessage({ type: 'SKIP_WAITING' });
            window.location.reload();
          });
        }
      });
    });
  } catch (error) {
    console.error('SW registration failed:', error);
  }
}
```

---

## 3. Caching Strategies

### Cache First (static assets — CSS, fonts, images)

```typescript
self.addEventListener('fetch', (event: FetchEvent) => {
  if (isStaticAsset(event.request.url)) {
    event.respondWith(
      caches.match(event.request).then(
        (cached) => cached ?? fetchAndCache(event.request, STATIC_CACHE)
      )
    );
  }
});
```

### Network First (API calls — fresh data preferred)

```typescript
async function networkFirst(request: Request, cache_name: string): Promise<Response> {
  try {
    const network_response = await fetch(request.clone());
    const cache = await caches.open(cache_name);
    cache.put(request, network_response.clone());
    return network_response;
  } catch {
    const cached = await caches.match(request);
    return cached ?? caches.match('/offline.html') as Promise<Response>;
  }
}
```

### Stale While Revalidate (balance: speed + freshness)

```typescript
async function staleWhileRevalidate(request: Request): Promise<Response> {
  const cache = await caches.open(DYNAMIC_CACHE);
  const cached = await cache.match(request);

  // Revalidate in background regardless
  const revalidate_promise = fetch(request).then((fresh) => {
    cache.put(request, fresh.clone());
    return fresh;
  });

  // Return cached immediately if available, else wait for network
  return cached ?? revalidate_promise;
}
```

### Strategy Router

```typescript
self.addEventListener('fetch', (event: FetchEvent) => {
  const { request } = event;
  const url = new URL(request.url);

  // Static assets → Cache First
  if (/\.(css|js|woff2|png|jpg|svg)$/.test(url.pathname)) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // API calls → Network First
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirst(request, DYNAMIC_CACHE));
    return;
  }

  // HTML pages → Stale While Revalidate
  if (request.headers.get('accept')?.includes('text/html')) {
    event.respondWith(staleWhileRevalidate(request));
    return;
  }
});
```

---

## 4. Push Notifications (Push API)

### Subscribe Client

```typescript
// src/push-notifications.ts
const VAPID_PUBLIC_KEY = import.meta.env.VITE_VAPID_PUBLIC_KEY;

function urlBase64ToUint8Array(base64_string: string): Uint8Array {
  const padding = '='.repeat((4 - (base64_string.length % 4)) % 4);
  const base64 = (base64_string + padding).replace(/-/g, '+').replace(/_/g, '/');
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
}

export async function subscribeToPush(): Promise<PushSubscription | null> {
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return null;

  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
  });

  // Send subscription to backend
  await fetch('/api/push/subscribe', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(subscription),
  });

  return subscription;
}
```

### Service Worker Push Handler

```typescript
// sw.ts
self.addEventListener('push', (event: PushEvent) => {
  const data = event.data?.json() ?? { title: 'Notification', body: '' };

  event.waitUntil(
    (self as ServiceWorkerGlobalScope).registration.showNotification(data.title, {
      body: data.body,
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png',
      data: { url: data.url ?? '/' },
      actions: [
        { action: 'view', title: 'View' },
        { action: 'dismiss', title: 'Dismiss' },
      ],
    })
  );
});

self.addEventListener('notificationclick', (event: NotificationEvent) => {
  event.notification.close();
  if (event.action === 'view' || !event.action) {
    event.waitUntil(
      (self as ServiceWorkerGlobalScope).clients.openWindow(
        event.notification.data.url
      )
    );
  }
});
```

### Backend: Send Push (Node.js)

```typescript
import webpush from 'web-push';

webpush.setVapidDetails(
  'mailto:admin@example.com',
  process.env.VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!
);

export async function sendPushNotification(
  subscription: webpush.PushSubscription,
  payload: { title: string; body: string; url: string }
): Promise<void> {
  await webpush.sendNotification(subscription, JSON.stringify(payload));
}
```

---

## 5. Workbox (Simplified Service Workers)

```bash
npm install workbox-webpack-plugin workbox-window
# or for Vite:
npm install vite-plugin-pwa
```

### vite-plugin-pwa Configuration

```typescript
// vite.config.ts
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/api\.example\.com\//,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'api-cache',
              expiration: { maxEntries: 50, maxAgeSeconds: 300 },
              networkTimeoutSeconds: 10,
            },
          },
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com\//,
            handler: 'StaleWhileRevalidate',
            options: { cacheName: 'google-fonts' },
          },
        ],
      },
      manifest: { /* see section 1 */ },
    }),
  ],
});
```

---

## 6. Background Sync (offline queue)

```typescript
// sw.ts
self.addEventListener('sync', (event: SyncEvent) => {
  if (event.tag === 'sync-messages') {
    event.waitUntil(syncOfflineMessages());
  }
});

async function syncOfflineMessages(): Promise<void> {
  const db = await openDB('offline-queue', 1);
  const pending = await db.getAll('messages');
  await Promise.all(
    pending.map(async (msg) => {
      await fetch('/api/messages', { method: 'POST', body: JSON.stringify(msg) });
      await db.delete('messages', msg.id);
    })
  );
}

// Client-side: queue when offline
async function sendMessage(message: object): Promise<void> {
  if (!navigator.onLine) {
    const db = await openDB('offline-queue', 1);
    await db.add('messages', message);
    await navigator.serviceWorker.ready.then((sw) =>
      sw.sync.register('sync-messages')
    );
    return;
  }
  await fetch('/api/messages', { method: 'POST', body: JSON.stringify(message) });
}
```

---

## Reference Docs

- [MDN Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Workbox docs](https://developer.chrome.com/docs/workbox)
- [vite-plugin-pwa](https://vite-pwa-org.netlify.app/)
- [Web Push Protocol](https://web.dev/articles/push-notifications-overview)
- [PWA Checklist (web.dev)](https://web.dev/articles/pwa-checklist)
- [web-push npm package](https://github.com/web-push-libs/web-push)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn đang dùng build tool nào? (Vite / Webpack / Next.js / CRA)"
2. "Tính năng PWA nào bạn cần? (offline caching / push notifications / installable / background sync)"
3. "Bạn muốn dùng Workbox hay viết service worker thủ công?"

Cung cấp code cụ thể và giải thích trade-off của từng caching strategy cho use case của họ.
