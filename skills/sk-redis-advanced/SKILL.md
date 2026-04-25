---
name: sk:redis-advanced
description: Redis Streams (XADD/XREAD), PubSub patterns, BullMQ v4+ queues, rate limiting (token bucket/sliding window), caching strategies (cache-aside/write-through), Redis Sentinel/Cluster setup.
license: MIT
argument-hint: "[streams|pubsub|bullmq|ratelimit|cache|cluster] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: database
  last_updated: "2026-04-25"
---

# Redis Advanced Skill

Redis beyond basic key-value: streams, queues, rate limiting, and high availability.

## When to Use

- Event streaming with Redis Streams
- Real-time messaging with PubSub
- Background job queues with BullMQ
- API rate limiting
- Advanced caching strategies
- High availability with Sentinel/Cluster

## Redis Streams

```typescript
import { createClient } from 'redis';
const redis = createClient({ url: 'redis://localhost:6379' });
await redis.connect();

// XADD - append to stream
const message_id = await redis.xAdd('events:orders', '*', {
  order_id: '123',
  user_id: '456',
  amount: '99.99',
  event: 'order.created'
});
// '*' = auto-generate ID (timestamp-sequence: 1714012345678-0)

// XREAD - read from stream
const results = await redis.xRead(
  [{ key: 'events:orders', id: '0' }], // '0' = from beginning, '$' = new only
  { COUNT: 10, BLOCK: 2000 }           // block 2s if no messages
);

// Consumer Groups - distributed processing
await redis.xGroupCreate('events:orders', 'order-processor', '0', { MKSTREAM: true });

// XREADGROUP - read as consumer
const messages = await redis.xReadGroup(
  'order-processor',  // group
  'worker-1',         // consumer name
  [{ key: 'events:orders', id: '>' }], // '>' = undelivered messages
  { COUNT: 5, BLOCK: 5000 }
);

// Process and ACK
for (const stream of messages ?? []) {
  for (const msg of stream.messages) {
    await processOrder(msg.message);
    await redis.xAck('events:orders', 'order-processor', msg.id);
  }
}

// XPENDING - check unacknowledged messages (for dead letter handling)
const pending = await redis.xPending('events:orders', 'order-processor', '-', '+', 10);
```

## PubSub Patterns

```typescript
// Publisher
const publisher = createClient({ url: 'redis://localhost:6379' });
await publisher.connect();

await publisher.publish('notifications:user:123', JSON.stringify({
  type: 'order_shipped',
  order_id: '456',
  timestamp: Date.now()
}));

// Subscriber (separate connection - cannot send commands while subscribed)
const subscriber = publisher.duplicate();
await subscriber.connect();

// Simple subscribe
await subscriber.subscribe('notifications:user:123', (message, channel) => {
  const event = JSON.parse(message);
  console.log(`[${channel}]`, event);
});

// Pattern subscribe (glob)
await subscriber.pSubscribe('notifications:*', (message, channel) => {
  // matches notifications:user:123, notifications:admin, etc.
});

// Keyspace notifications (config required: notify-keyspace-events KEA)
await subscriber.pSubscribe('__keyevent@0__:expired', (key) => {
  console.log('Key expired:', key);
});
```

## BullMQ (Bull v4+)

```typescript
import { Queue, Worker, QueueEvents, FlowProducer } from 'bullmq';

const connection = { host: 'localhost', port: 6379 };

// Create queue
const email_queue = new Queue('email', { connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 1000 },
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 50 },
  }
});

// Add jobs
await email_queue.add('welcome', { to: 'user@example.com', name: 'Alice' });
await email_queue.add('invoice', { user_id: '123' }, {
  delay: 5000,          // delay 5s
  priority: 1,          // lower number = higher priority
  jobId: 'inv-123',     // idempotent job ID
  repeat: { every: 60000, limit: 10 } // repeat every minute, max 10 times
});

// Worker
const worker = new Worker('email', async (job) => {
  switch (job.name) {
    case 'welcome':
      await sendWelcomeEmail(job.data);
      break;
    case 'invoice':
      await generateAndSendInvoice(job.data);
      break;
  }
  return { sent_at: new Date().toISOString() }; // stored as returnvalue
}, {
  connection,
  concurrency: 5,
  limiter: { max: 100, duration: 60000 } // 100 jobs per minute
});

worker.on('completed', (job) => console.log(`Job ${job.id} done`));
worker.on('failed', (job, err) => console.error(`Job ${job?.id} failed:`, err));

// Flow (parent-child dependencies)
const flow = new FlowProducer({ connection });
await flow.add({
  name: 'process-order',
  queueName: 'orders',
  data: { order_id: '123' },
  children: [
    { name: 'charge', queueName: 'payments', data: { amount: 99 } },
    { name: 'reserve', queueName: 'inventory', data: { sku: 'ABC' } }
  ]
}); // parent waits for all children to complete
```

## Rate Limiting

### Token Bucket (using redis-rate-limiter)

```typescript
import { RateLimiterRedis } from 'rate-limiter-flexible';

const rate_limiter = new RateLimiterRedis({
  storeClient: redis,
  keyPrefix: 'rl:api',
  points: 100,       // 100 requests
  duration: 60,      // per 60 seconds
  blockDuration: 0,  // don't block, just reject
});

// Express/Fastify middleware
async function rateLimitMiddleware(req, res, next) {
  try {
    const result = await rate_limiter.consume(req.ip);
    res.setHeader('X-RateLimit-Remaining', result.remainingPoints);
    next();
  } catch (err) {
    res.setHeader('Retry-After', Math.ceil(err.msBeforeNext / 1000));
    res.status(429).json({ error: 'Too Many Requests' });
  }
}
```

### Sliding Window (Lua script - atomic)

```typescript
const SLIDING_WINDOW_SCRIPT = `
local key = KEYS[1]
local window = tonumber(ARGV[1])
local limit = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
local count = redis.call('ZCARD', key)

if count < limit then
  redis.call('ZADD', key, now, now)
  redis.call('EXPIRE', key, math.ceil(window/1000))
  return 1  -- allowed
end
return 0  -- blocked
`;

async function checkSlidingWindow(user_id: string, limit: number, window_ms: number) {
  const key = `rl:sliding:${user_id}`;
  const now = Date.now();
  const result = await redis.eval(SLIDING_WINDOW_SCRIPT, {
    keys: [key], arguments: [String(window_ms), String(limit), String(now)]
  });
  return result === 1;
}
```

## Caching Strategies

```typescript
// Cache-aside (lazy loading)
async function getUser(id: string) {
  const cache_key = `user:${id}`;
  const cached = await redis.get(cache_key);
  if (cached) return JSON.parse(cached);

  const user = await db.user.findUnique({ where: { id } });
  if (user) await redis.setEx(cache_key, 3600, JSON.stringify(user)); // TTL 1h
  return user;
}

// Write-through (always write to cache + DB)
async function updateUser(id: string, data: Partial<User>) {
  const user = await db.user.update({ where: { id }, data });
  await redis.setEx(`user:${id}`, 3600, JSON.stringify(user));
  return user;
}

// Cache stampede prevention (single flight)
const in_flight = new Map<string, Promise<any>>();

async function cachedFetch(key: string, fetcher: () => Promise<any>, ttl = 3600) {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);

  if (in_flight.has(key)) return in_flight.get(key);

  const promise = fetcher().then(data => {
    redis.setEx(key, ttl, JSON.stringify(data));
    in_flight.delete(key);
    return data;
  });

  in_flight.set(key, promise);
  return promise;
}
```

## Sentinel & Cluster

```typescript
// Sentinel (high availability, auto-failover)
import { createClient } from 'redis';

const client = createClient({
  sentinels: [
    { host: 'sentinel-1', port: 26379 },
    { host: 'sentinel-2', port: 26379 },
  ],
  name: 'mymaster', // sentinel master name
});

// Cluster (horizontal scaling)
import { createCluster } from 'redis';

const cluster = createCluster({
  rootNodes: [
    { host: 'redis-node-1', port: 6379 },
    { host: 'redis-node-2', port: 6379 },
    { host: 'redis-node-3', port: 6379 },
  ],
  defaults: { password: process.env.REDIS_PASSWORD },
});
await cluster.connect();
```

## Resources

- redis npm: https://github.com/redis/node-redis
- BullMQ: https://docs.bullmq.io
- rate-limiter-flexible: https://github.com/animir/node-rate-limiter-flexible
- Redis commands: https://redis.io/commands

## User Interaction (MANDATORY)

When activated, ask:

1. **Use case:** "Bạn cần dùng Redis cho việc gì? (queue/cache/pubsub/streams/rate-limit)"
2. **Scale:** "Expected load? (req/s, concurrent workers, data size)"
3. **Stack:** "Node.js/Go/Python? Redis version?"

Then provide production-ready implementation with connection handling.
