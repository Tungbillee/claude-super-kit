---
name: sk:message-queues
description: Kafka (producers/consumers/partitions/consumer groups), RabbitMQ (exchanges/queues/bindings/ack patterns), NATS (subjects/JetStream), comparison guide, DLQ patterns. Event-driven architecture.
license: MIT
argument-hint: "[kafka|rabbitmq|nats|compare|dlq|patterns] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: messaging
  last_updated: "2026-04-25"
---

# Message Queues Skill

Kafka, RabbitMQ, and NATS for reliable async messaging and event streaming.

## When to Use

- Decoupling services with async messaging
- Event streaming and log aggregation (Kafka)
- Task queues and work distribution (RabbitMQ)
- Lightweight pub/sub with cloud-native (NATS)
- Implementing reliable message processing with DLQ
- Choosing between messaging systems

## Kafka

### Producer & Consumer

```typescript
import { Kafka, CompressionTypes, logLevel } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'order-service',
  brokers: ['kafka-1:9092', 'kafka-2:9092', 'kafka-3:9092'],
  ssl: true,
  sasl: { mechanism: 'plain', username: process.env.KAFKA_USER!, password: process.env.KAFKA_PASS! },
  retry: { initialRetryTime: 100, retries: 8 },
  logLevel: logLevel.WARN,
});

// Producer
const producer = kafka.producer({
  idempotent: true,                  // exactly-once delivery
  maxInFlightRequests: 5,
  transactionalId: 'order-producer', // for transactions
});
await producer.connect();

await producer.send({
  topic: 'orders.created',
  compression: CompressionTypes.GZIP,
  messages: [
    {
      key: order.user_id,            // same key → same partition (ordering guarantee)
      value: JSON.stringify(order),
      headers: { 'content-type': 'application/json', 'event-version': '1' },
      timestamp: Date.now().toString(),
    }
  ],
});

// Transactional producer (exactly-once across multiple topics)
const transaction = await producer.transaction();
try {
  await transaction.send({ topic: 'orders.created', messages: [{ value: JSON.stringify(order) }] });
  await transaction.send({ topic: 'inventory.reserved', messages: [{ value: JSON.stringify(reservation) }] });
  await transaction.commit();
} catch (err) {
  await transaction.abort();
  throw err;
}

// Consumer
const consumer = kafka.consumer({
  groupId: 'order-processor',        // consumer group - Kafka distributes partitions
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
  maxBytesPerPartition: 1048576,     // 1MB
});
await consumer.connect();
await consumer.subscribe({ topics: ['orders.created'], fromBeginning: false });

await consumer.run({
  autoCommit: false,                 // manual commit for at-least-once
  eachMessage: async ({ topic, partition, message, heartbeat }) => {
    const order = JSON.parse(message.value!.toString());
    try {
      await processOrder(order);
      await consumer.commitOffsets([{ topic, partition, offset: (Number(message.offset) + 1).toString() }]);
    } catch (err) {
      // Send to DLT (Dead Letter Topic)
      await producer.send({
        topic: 'orders.created.DLT',
        messages: [{ key: message.key, value: message.value,
          headers: { ...message.headers, 'error': String(err), 'original-topic': topic } }]
      });
      // Still commit to avoid blocking
      await consumer.commitOffsets([{ topic, partition, offset: (Number(message.offset) + 1).toString() }]);
    }
  },
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  await consumer.disconnect();
  await producer.disconnect();
});
```

### Topic & Partition Design

```bash
# Create topic with retention
kafka-topics.sh --create \
  --topic orders.created \
  --partitions 12 \          # parallelism = min(partitions, consumers in group)
  --replication-factor 3 \   # tolerate 2 broker failures
  --config retention.ms=604800000 \    # 7 days
  --config compression.type=gzip \
  --bootstrap-server kafka:9092

# Rule of thumb: partitions = 2x expected consumers, max throughput / (consumer throughput)
```

## RabbitMQ

### Exchanges, Queues, Bindings

```typescript
import amqplib from 'amqplib';

const connection = await amqplib.connect({
  protocol: 'amqps',
  hostname: 'rabbitmq.example.com',
  username: process.env.RABBIT_USER,
  password: process.env.RABBIT_PASS,
  vhost: '/production',
  heartbeat: 60,
});
const channel = await connection.createConfirmChannel(); // publisher confirms

// Topic exchange (routing by pattern)
await channel.assertExchange('events', 'topic', { durable: true });

// Queue with DLX (Dead Letter Exchange)
await channel.assertExchange('events.dlx', 'direct', { durable: true });
await channel.assertQueue('events.dlq', { durable: true });
await channel.bindQueue('events.dlq', 'events.dlx', 'dead');

await channel.assertQueue('order-processor', {
  durable: true,
  arguments: {
    'x-dead-letter-exchange': 'events.dlx',
    'x-dead-letter-routing-key': 'dead',
    'x-message-ttl': 3600000,         // 1h TTL
    'x-max-length': 10000,            // max 10k messages
    'x-queue-type': 'quorum',         // quorum queues for HA (vs classic/stream)
  }
});

// Bind queue to exchange with routing key pattern
await channel.bindQueue('order-processor', 'events', 'orders.*');
await channel.bindQueue('order-processor', 'events', 'payments.completed');

// Publish
await channel.publish('events', 'orders.created',
  Buffer.from(JSON.stringify(order)),
  {
    persistent: true,                  // survives broker restart
    contentType: 'application/json',
    messageId: order.id,
    timestamp: Date.now(),
    headers: { 'retry-count': 0 },
  },
  (err) => { if (err) console.error('Publish failed:', err); }
);
```

### Consumer with Ack Patterns

```typescript
const consumer_channel = await connection.createChannel();
await consumer_channel.prefetch(10); // process max 10 concurrent messages

await consumer_channel.consume('order-processor', async (msg) => {
  if (!msg) return; // consumer cancelled

  const order = JSON.parse(msg.content.toString());
  const retry_count = (msg.properties.headers?.['retry-count'] ?? 0) as number;

  try {
    await processOrder(order);
    consumer_channel.ack(msg);                    // success - remove from queue
  } catch (err) {
    if (retry_count < 3) {
      // Republish with incremented retry count + delay (via delayed exchange plugin)
      consumer_channel.nack(msg, false, false);   // reject, send to DLX
    } else {
      console.error('Max retries exceeded:', order.id, err);
      consumer_channel.nack(msg, false, false);   // to DLQ permanently
    }
  }
}, { noAck: false }); // manual ack required

// Exchange types:
// direct  - exact routing key match
// topic   - wildcard patterns (*.order.# → 0+ words)
// fanout  - broadcast to all bound queues (ignore routing key)
// headers - match on message headers (rarely used)
```

## NATS

### Core & JetStream

```typescript
import { connect, StringCodec, JSONCodec, nanos } from 'nats';

const nc = await connect({
  servers: ['nats://nats-1:4222', 'nats://nats-2:4222'],
  token: process.env.NATS_TOKEN,
  reconnect: true,
  maxReconnectAttempts: -1,       // unlimited
  reconnectTimeWait: 2000,
});

const jc = JSONCodec();
const sc = StringCodec();

// Core NATS - fire and forget (no persistence)
nc.publish('orders.created', jc.encode(order));

// Subscribe
const sub = nc.subscribe('orders.*', {
  queue: 'order-processors'       // queue group = load balancing
});
for await (const msg of sub) {
  const order = jc.decode(msg.data);
  msg.respond(jc.encode({ status: 'processing' })); // request-reply pattern
}

// JetStream - persistent, at-least-once delivery
const js = nc.jetstream();
const jsm = await nc.jetstreamManager();

// Create stream
await jsm.streams.add({
  name: 'ORDERS',
  subjects: ['orders.>'],           // '>' = all sub-subjects
  retention: 'limits',
  max_age: nanos(7 * 24 * 60 * 60 * 1000), // 7 days in nanoseconds
  storage: 'file',
  replicas: 3,
});

// Publish with acknowledgment
const pub_ack = await js.publish('orders.created', jc.encode(order));
console.log(`Published to seq ${pub_ack.seq}`);

// Push consumer (streaming)
const consumer = await js.consumers.get('ORDERS', 'order-processor');
const messages = await consumer.consume({ max_messages: 10 });
for await (const msg of messages) {
  await processOrder(jc.decode(msg.data));
  msg.ack();                        // or msg.nak() / msg.term()
}
```

## DLQ Patterns

```typescript
// Universal DLQ handler
interface DeadLetterMessage {
  original_topic: string;
  payload: unknown;
  error: string;
  attempts: number;
  failed_at: string;
}

// 1. Store in database for manual review
async function handleDeadLetter(msg: DeadLetterMessage) {
  await db.dead_letters.create({
    data: {
      topic: msg.original_topic,
      payload: JSON.stringify(msg.payload),
      error: msg.error,
      attempts: msg.attempts,
      failed_at: new Date(msg.failed_at),
    }
  });
  // Alert ops team
  await alerts.send(`DLQ: ${msg.original_topic} - ${msg.error}`);
}

// 2. Exponential backoff retry
function calcBackoff(attempt: number): number {
  return Math.min(1000 * Math.pow(2, attempt), 30000); // max 30s
}
```

## Choosing a Message Queue

| Factor | Kafka | RabbitMQ | NATS |
|--------|-------|----------|------|
| Throughput | Very high (millions/s) | High (50k+/s) | Very high |
| Message replay | Yes (retention) | No (consumed = gone) | JetStream only |
| Ordering | Per-partition | Per-queue | Per-consumer |
| Routing | Topic/key | Exchange patterns | Subject hierarchy |
| Ops complexity | High | Medium | Low |
| Best for | Event streaming, audit log | Task queues, RPC | Cloud-native, IoT |
| Persistence | Always | Optional | JetStream only |

**Rules of thumb:**
- Need replay/audit → Kafka
- Complex routing + RPC → RabbitMQ
- Simple, fast, cloud-native → NATS
- Already using Redis → BullMQ (see `sk:redis-advanced`)

## Resources

- KafkaJS: https://kafka.js.org/docs/getting-started
- amqplib: https://amqplib.github.io/amqplib.node
- NATS.js: https://github.com/nats-io/nats.js
- Kafka patterns: https://www.confluent.io/blog/event-driven-microservices-kafka

## User Interaction (MANDATORY)

When activated, ask:

1. **System:** "Đang dùng Kafka, RabbitMQ hay NATS? Hay đang chọn giữa chúng?"
2. **Use case:** "Event streaming, task queue, hay pub/sub realtime?"
3. **Reliability:** "Cần message ordering? At-least-once hay exactly-once delivery?"

Then provide production-ready implementation with error handling and DLQ setup.
