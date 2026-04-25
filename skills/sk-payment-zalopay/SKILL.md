---
name: sk:payment-zalopay
description: "ZaloPay gateway — MAC verification, order creation, callback handling, reconciliation API, sandbox testing"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: payment-vn
last_updated: 2026-04-25
license: MIT
---

# sk:payment-zalopay — ZaloPay Payment Integration

## Overview

ZaloPay (by VNG) is tightly integrated with Zalo ecosystem. Uses HMAC-SHA256 MAC for request signing. Two main APIs: `/v2/create` (initiate) and `/v2/query` (status).

**SECURITY RULE:** `key1` and `key2` must never be logged or sent to client. `key1` signs requests, `key2` verifies callbacks.

## Environment Config

```typescript
// config/zalopay.ts
export const ZALOPAY_CONFIG = {
  app_id:     Number(process.env.ZALOPAY_APP_ID!),
  key1:       process.env.ZALOPAY_KEY1!,   // for signing requests — NEVER log
  key2:       process.env.ZALOPAY_KEY2!,   // for verifying callbacks — NEVER log
  baseUrl: process.env.NODE_ENV === 'production'
    ? 'https://openapi.zalopay.vn'
    : 'https://sb-openapi.zalopay.vn',
  callback_url: process.env.ZALOPAY_CALLBACK_URL!
}
```

## Create Order

```typescript
// lib/zalopay-client.ts
import crypto from 'node:crypto'

interface CreateOrderInput {
  order_id: string       // app_trans_id: unique per day, format: yyMMdd_<id>
  amount: number         // VND integer
  description: string
  items?: object[]       // product details (optional)
  embed_data?: object    // custom metadata
  user_id?: string
}

interface ZaloPayOrderResponse {
  return_code: number    // 1 = success, 2 = fail, 3 = pending
  return_message: string
  order_url: string      // redirect user here
  zp_trans_token: string
  order_token: string
  qr_code?: string
}

export async function createOrder(
  input: CreateOrderInput
): Promise<ZaloPayOrderResponse> {
  // ZaloPay requires yyMMdd_ prefix on trans_id
  const app_trans_id = `${getDatePrefix()}_${input.order_id}`
  const app_time = Date.now()
  const embed_data = JSON.stringify(input.embed_data ?? { callback_url: ZALOPAY_CONFIG.callback_url })
  const items = JSON.stringify(input.items ?? [])

  // MAC raw string — field order is CRITICAL
  const raw_mac = [
    ZALOPAY_CONFIG.app_id,
    app_trans_id,
    input.user_id ?? 'guest',
    input.amount,
    app_time,
    embed_data,
    items
  ].join('|')

  const mac = crypto
    .createHmac('sha256', ZALOPAY_CONFIG.key1)
    .update(raw_mac)
    .digest('hex')

  const payload = {
    app_id:       ZALOPAY_CONFIG.app_id,
    app_trans_id,
    app_user:     input.user_id ?? 'guest',
    app_time,
    amount:       input.amount,
    item:         items,
    embed_data,
    description:  input.description,
    callback_url: ZALOPAY_CONFIG.callback_url,
    mac
  }

  const form = new URLSearchParams(
    Object.entries(payload).map(([k, v]) => [k, String(v)])
  )

  const res = await fetch(`${ZALOPAY_CONFIG.baseUrl}/v2/create`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form
  })

  const data = await res.json()
  if (data.return_code !== 1) {
    throw new Error(`ZaloPay create failed: [${data.return_code}] ${data.return_message}`)
  }
  return data
}

function getDatePrefix(): string {
  const d = new Date()
  const yy = String(d.getFullYear()).slice(-2)
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  return `${yy}${mm}${dd}`
}
```

## Query Order Status

```typescript
export async function queryOrder(app_trans_id: string) {
  const raw_mac = [
    ZALOPAY_CONFIG.app_id,
    app_trans_id,
    ZALOPAY_CONFIG.key1
  ].join('|')

  const mac = crypto
    .createHmac('sha256', ZALOPAY_CONFIG.key1)
    .update(raw_mac)
    .digest('hex')

  const form = new URLSearchParams({
    app_id:       String(ZALOPAY_CONFIG.app_id),
    app_trans_id,
    mac
  })

  const res = await fetch(`${ZALOPAY_CONFIG.baseUrl}/v2/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form
  })

  return res.json() as Promise<{
    return_code: number    // 1=paid, 2=rejected, 3=pending
    return_message: string
    zp_trans_id?: number
    amount?: number
    server_time?: number
  }>
}
```

## Callback / Webhook Handler (Next.js)

```typescript
// app/api/webhooks/zalopay/route.ts
import { NextRequest, NextResponse } from 'next/server'
import crypto from 'node:crypto'

interface ZaloPayCallback {
  data: string      // JSON string of transaction data
  mac: string       // HMAC-SHA256(data, key2)
  type: number      // 1 = payment success
}

export async function POST(req: NextRequest) {
  const body: ZaloPayCallback = await req.json()
  const { data, mac: received_mac, type } = body

  // 1. Verify MAC using key2 (NOT key1)
  const expected_mac = crypto
    .createHmac('sha256', ZALOPAY_CONFIG.key2)
    .update(data)
    .digest('hex')

  if (!crypto.timingSafeEqual(
    Buffer.from(expected_mac),
    Buffer.from(received_mac)
  )) {
    return NextResponse.json({ return_code: -1, return_message: 'Invalid MAC' })
  }

  // 2. Parse transaction data
  const tx_data = JSON.parse(data) as {
    app_id: number
    app_trans_id: string
    app_time: number
    app_user: string
    amount: number
    embed_data: string
    item: string
    zp_trans_id: number
    server_time: number
    channel: number
    merchant_user_id: string
    user_fee_amount: number
    discount_amount: number
  }

  // 3. Process (idempotent — ZaloPay may retry on failure)
  try {
    const order_id = tx_data.app_trans_id.split('_').slice(1).join('_')
    await fulfillOrder(order_id, {
      zp_trans_id: tx_data.zp_trans_id,
      amount: tx_data.amount
    })
  } catch (e) {
    console.error('[zalopay] fulfillOrder failed:', e)
    return NextResponse.json({ return_code: 0, return_message: 'failed' })
  }

  // ZaloPay requires return_code: 1 for success acknowledgment
  return NextResponse.json({ return_code: 1, return_message: 'success' })
}
```

## Reconciliation API

```typescript
export async function getDailyReconciliation(date: string) {
  // date: format yyyy-MM-dd
  const raw_mac = [
    ZALOPAY_CONFIG.app_id,
    date,
    ZALOPAY_CONFIG.key1
  ].join('|')

  const mac = crypto
    .createHmac('sha256', ZALOPAY_CONFIG.key1)
    .update(raw_mac)
    .digest('hex')

  const form = new URLSearchParams({
    app_id: String(ZALOPAY_CONFIG.app_id),
    date,
    mac
  })

  const res = await fetch(`${ZALOPAY_CONFIG.baseUrl}/v2/reconciliation`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form
  })

  return res.json() as Promise<{
    return_code: number
    return_message: string
    data: Array<{
      app_trans_id: string
      zp_trans_id: number
      amount: number
      status: number
      server_time: number
    }>
  }>
}
```

## Return Codes

| Code | Meaning | Action |
|------|---------|--------|
| `1` | Success / paid | Fulfill order |
| `2` | Failed / rejected | Cancel order |
| `3` | Pending | Query again later |
| `-1` | System error | Retry |
| `-2` | App ID invalid | Check config |
| `-3` | MAC invalid | Check key1/key2 |
| `-4` | Request invalid | Check params |
| `-5` | Trans not found | Wrong trans_id |
| `-6` | Trans already processed | Idempotency OK |
| `-49` | Spam / abuse | Block user |

## MAC Key Reference

| Operation | Key used |
|-----------|---------|
| Create order request | `key1` |
| Query order request | `key1` |
| Reconciliation request | `key1` |
| Verify callback (POST from ZaloPay) | `key2` |

## Sandbox Testing

- Sandbox URL: `https://sb-openapi.zalopay.vn`
- Get sandbox credentials: https://docs.zalopay.vn/docs/developer/sandbox
- Test wallet: use ZaloPay app in sandbox mode
- Sandbox app_id + keys provided in developer portal

## Security Checklist

- [ ] `key1` and `key2` stored in env only, never committed
- [ ] Callback verified with `key2` before processing
- [ ] Use `crypto.timingSafeEqual` for MAC comparison
- [ ] Return `return_code: 1` to ZaloPay after successful processing
- [ ] Idempotency: check if `app_trans_id` already fulfilled before processing
- [ ] `app_trans_id` includes date prefix (ZaloPay resets daily uniqueness window)

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "ZaloPay integration task?",
      header: "Task",
      options: [
        { label: "Create order", description: "Init payment + get redirect URL" },
        { label: "Callback handler", description: "Verify + process ZaloPay POST" },
        { label: "Query status", description: "Check order payment status" },
        { label: "Reconciliation", description: "Daily transaction report" }
      ]
    },
    {
      question: "Environment?",
      header: "Env",
      options: [
        { label: "Sandbox", description: "sb-openapi.zalopay.vn — testing" },
        { label: "Production", description: "openapi.zalopay.vn — live" }
      ]
    }
  ]
})
```
