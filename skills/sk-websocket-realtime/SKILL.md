---
name: sk:websocket-realtime
description: Real-time communication with Socket.io (rooms, namespaces, broadcasting, fallback transports), native WebSocket API, WebRTC data channels, MQTT for IoT, Server-Sent Events.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: realtime
argument-hint: "[realtime feature or protocol choice]"
---

# sk:websocket-realtime

Complete guide for real-time communication patterns — from simple WebSocket to full-featured Socket.io and IoT with MQTT.

## When to Use

- Building live chat, notifications, or collaborative features
- Streaming real-time data (dashboards, feeds, game state)
- Choosing between WebSocket, SSE, Socket.io, or MQTT
- Implementing rooms/channels for multi-user experiences
- Scaling WebSocket connections across multiple servers
- IoT device communication with MQTT

---

## 1. Protocol Selection Guide

| Protocol | Best For | Bidirectional | Overhead | Reconnect |
|---|---|---|---|---|
| WebSocket | Custom realtime, low latency | Yes | Low | Manual |
| Socket.io | Chat, collaboration, fallback needed | Yes | Medium | Automatic |
| SSE | Server push only (feeds, notifications) | No (server→client) | Low | Automatic |
| MQTT | IoT, high-volume telemetry | Yes | Very low | Automatic |
| WebRTC | P2P video/audio/data | Yes (P2P) | High setup | Manual |

---

## 2. Socket.io — Server Setup

```bash
npm install socket.io
```

```typescript
// src/socket-server.ts
import { createServer } from 'http';
import { Server, Socket } from 'socket.io';
import express from 'express';

const app = express();
const http_server = createServer(app);

const io = new Server(http_server, {
  cors: {
    origin: ['http://localhost:3000', 'https://example.com'],
    methods: ['GET', 'POST'],
  },
  transports: ['websocket', 'polling'],  // websocket first, polling fallback
  pingTimeout: 20000,
  pingInterval: 10000,
});

// Authentication middleware
io.use((socket: Socket, next) => {
  const token = socket.handshake.auth.token;
  try {
    const user = verifyJWT(token);
    socket.data.user = user;
    next();
  } catch {
    next(new Error('Authentication failed'));
  }
});

io.on('connection', (socket: Socket) => {
  const user = socket.data.user;
  console.log(`User ${user.id} connected: ${socket.id}`);

  // Join user to their personal room
  socket.join(`user:${user.id}`);

  socket.on('disconnect', (reason) => {
    console.log(`User ${user.id} disconnected: ${reason}`);
  });
});

http_server.listen(3001);
export { io };
```

---

## 3. Socket.io — Rooms and Namespaces

### Rooms (dynamic channels)

```typescript
// Join/leave rooms
socket.on('join_room', (room_id: string) => {
  socket.join(room_id);
  socket.to(room_id).emit('user_joined', { user_id: socket.data.user.id });
});

socket.on('leave_room', (room_id: string) => {
  socket.leave(room_id);
  socket.to(room_id).emit('user_left', { user_id: socket.data.user.id });
});

// Send message to room
socket.on('send_message', async ({ room_id, content }: { room_id: string; content: string }) => {
  const message = await saveMessage({ room_id, content, user_id: socket.data.user.id });
  // Broadcast to room (including sender)
  io.to(room_id).emit('new_message', message);
});

// Admin: broadcast to all
io.emit('announcement', { text: 'Server maintenance in 5 minutes' });

// Specific socket
io.to(socket.id).emit('private_message', { from: 'admin', text: 'Hello' });

// User's personal room (across their devices)
io.to(`user:${target_user_id}`).emit('notification', notification_data);
```

### Namespaces (feature isolation)

```typescript
// Chat namespace
const chat_ns = io.of('/chat');
chat_ns.on('connection', (socket) => {
  socket.on('message', (data) => { /* chat logic */ });
});

// Admin namespace with extra middleware
const admin_ns = io.of('/admin');
admin_ns.use((socket, next) => {
  if (socket.data.user.role !== 'admin') return next(new Error('Unauthorized'));
  next();
});
admin_ns.on('connection', (socket) => {
  // admin-only events
  socket.on('kick_user', (user_id: string) => {
    io.to(`user:${user_id}`).disconnectSockets(true);
  });
});
```

---

## 4. Socket.io — Client (React)

```typescript
// lib/socket-client.ts
import { io, Socket } from 'socket.io-client';

let socket: Socket | null = null;

export function initSocket(token: string): Socket {
  if (socket?.connected) return socket;

  socket = io('https://api.example.com', {
    auth: { token },
    transports: ['websocket'],
    reconnection: true,
    reconnectionDelay: 1000,
    reconnectionAttempts: 5,
  });

  socket.on('connect_error', (err) => {
    console.error('Socket connection error:', err.message);
  });

  return socket;
}

export function getSocket(): Socket {
  if (!socket) throw new Error('Socket not initialized');
  return socket;
}
```

```typescript
// hooks/useSocket.ts
import { useEffect, useState } from 'react';
import { Socket } from 'socket.io-client';
import { initSocket } from '../lib/socket-client';

export function useSocket(token: string) {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const s = initSocket(token);
    s.on('connect', () => setConnected(true));
    s.on('disconnect', () => setConnected(false));
    setSocket(s);

    return () => { s.disconnect(); };
  }, [token]);

  return { socket, connected };
}

// hooks/useRoom.ts
export function useRoom(socket: Socket | null, room_id: string) {
  const [messages, setMessages] = useState<Message[]>([]);

  useEffect(() => {
    if (!socket || !room_id) return;

    socket.emit('join_room', room_id);
    socket.on('new_message', (msg: Message) => {
      setMessages((prev) => [...prev, msg]);
    });

    return () => {
      socket.emit('leave_room', room_id);
      socket.off('new_message');
    };
  }, [socket, room_id]);

  const sendMessage = (content: string) => {
    socket?.emit('send_message', { room_id, content });
  };

  return { messages, sendMessage };
}
```

---

## 5. Native WebSocket API

```typescript
// server: ws library
import { WebSocketServer, WebSocket } from 'ws';

const wss = new WebSocketServer({ port: 8080 });
const clients = new Map<string, WebSocket>();

wss.on('connection', (ws, req) => {
  const client_id = generateId();
  clients.set(client_id, ws);

  ws.on('message', (data) => {
    const message = JSON.parse(data.toString());
    // Broadcast to all clients
    clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ ...message, from: client_id }));
      }
    });
  });

  ws.on('close', () => clients.delete(client_id));

  // Heartbeat
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
});

// Heartbeat interval to detect dead connections
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);
```

```typescript
// Client: auto-reconnect WebSocket wrapper
class ReliableWebSocket {
  private ws: WebSocket | null = null;
  constructor(private url: string, private on_message: (data: unknown) => void) { this.connect(); }

  private connect() {
    this.ws = new WebSocket(this.url);
    this.ws.onmessage = (e) => this.on_message(JSON.parse(e.data));
    this.ws.onclose = () => setTimeout(() => this.connect(), 2000);
    this.ws.onerror = (e) => console.error('WS error', e);
  }

  send(data: unknown) {
    this.ws?.readyState === WebSocket.OPEN
      ? this.ws.send(JSON.stringify(data))
      : console.warn('WS not connected');
  }
}
```

---

## 6. Server-Sent Events (SSE)

Best for: one-way server push (notifications, feeds). EventSource auto-reconnects.

```typescript
// Express SSE
app.get('/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.flushHeaders();

  const send = (event: string, data: unknown) =>
    res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);

  const unsub = eventBus.subscribe('notification', (n) => send('notification', n));
  const hb = setInterval(() => res.write(':heartbeat\n\n'), 15000);
  req.on('close', () => { clearInterval(hb); unsub(); });
});

// Client
const es = new EventSource('/events');
es.addEventListener('notification', (e) => showNotification(JSON.parse(e.data)));
```

---

## 7. MQTT for IoT

```bash
npm install mqtt
```

```typescript
import mqtt from 'mqtt';

const client = mqtt.connect('mqtts://broker.example.com:8883', {
  clientId: `device_${process.env.DEVICE_ID}`,
  username: process.env.MQTT_USER,
  password: process.env.MQTT_PASS,
  reconnectPeriod: 5000,
  will: { topic: `devices/${process.env.DEVICE_ID}/status`, payload: JSON.stringify({ online: false }), qos: 1, retain: true },
});

client.on('connect', () => {
  client.subscribe(`devices/${process.env.DEVICE_ID}/commands`, { qos: 1 });
  client.publish(`devices/${process.env.DEVICE_ID}/status`, JSON.stringify({ online: true }), { retain: true });
});

client.on('message', (topic, payload) => executeCommand(JSON.parse(payload.toString())));

// Telemetry every 10s (QoS 0 = fire-and-forget)
setInterval(() => {
  client.publish(`devices/${process.env.DEVICE_ID}/telemetry`,
    JSON.stringify({ temperature: readSensor(), timestamp: Date.now() }), { qos: 0 });
}, 10000);
```

QoS: `0` fire-and-forget (telemetry) | `1` at-least-once (commands) | `2` exactly-once (critical)

---

## 8. Scaling Socket.io (Redis Adapter)

```bash
npm install @socket.io/redis-adapter ioredis
```

```typescript
import { createClient } from 'ioredis';
import { createAdapter } from '@socket.io/redis-adapter';

const pub_client = createClient({ host: 'redis', port: 6379 });
const sub_client = pub_client.duplicate();
await Promise.all([pub_client.connect(), sub_client.connect()]);
io.adapter(createAdapter(pub_client, sub_client));
// io.to(room).emit() now works across all server instances
```

---

## Reference Docs

- [Socket.io Docs](https://socket.io/docs/v4/)
- [Socket.io Redis Adapter](https://socket.io/docs/v4/redis-adapter/)
- [ws npm package](https://github.com/websockets/ws)
- [MDN WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [MDN Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [MQTT.js](https://github.com/mqttjs/MQTT.js)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Use case của bạn là gì? (live chat / notifications / realtime dashboard / collaborative editing / IoT)"
2. "Bạn cần bidirectional (client↔server) hay chỉ server push?"
3. "Scale requirement: bao nhiêu concurrent connections? Cần multiple servers không?"
4. "Framework backend: Express / Fastify / Next.js / NestJS?"

Cung cấp implementation đầy đủ cho protocol phù hợp nhất với use case của họ.
