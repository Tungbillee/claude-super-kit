---
name: sk:payment-pay2s
description: "Pay2s Vietnamese payment gateway — initiation, QR, status check, webhook HMAC verification, reconciliation"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: payment-vn
last_updated: 2026-04-25
license: MIT
---

# sk:payment-pay2s — Pay2s Payment Integration

## Overview

Pay2s is a Vietnamese payment aggregator supporting bank transfer, QR code, and e-wallet payments.

**SECURITY RULE:** Never log `secret_key`, `access_token`, or raw webhook body before signature verification.

## Environment Config

```typescript
// config/pay2s.ts
export const PAY2S_CONFIG = {
  base_url: process.env.NODE_ENV === 'production'
    ? 'https://api.pay2s.vn/v1'
    : 'https://sandbox.pay2s.vn/v1',
  merchant_id: process.env.PAY2S_MERCHANT_ID!,
  access_token: process.env.PAY2S_ACCESS_TOKEN!,
  secret_key: process.env.PAY2S_SECRET_KEY!,   // NEVER log this
  webhook_secret: process.env.PAY2S_WEBHOOK_SECRET!
}
```

## Payment Initiation

```typescript
// lib/pay2s-client.ts
import crypto from 'node:crypto'

interface CreatePaymentInput {
  order_id: string        // your unique order ID
  amount: number          // VND, integer
  description: string     // max 50 chars
  return_url: string      // redirect after payment
  cancel_url: string
  customer_email?: string
  customer_phone?: string
}

interface PaymentResponse {
  success: boolean
  payment_id: string
  payment_url: string     // redirect user here
  qr_code?: string        // base64 QR image
  expired_at: string      // ISO datetime
}

export async function createPayment(
  input: CreatePaymentInput
): Promise<PaymentResponse> {
  const timestamp = Date.now().toString()
  const signature = generateSignature({
    merchant_id: PAY2S_CONFIG.merchant_id,
    order_id: input.order_id,
    amount: input.amount.toString(),
    timestamp
  }, PAY2S_CONFIG.secret_key)

  const res = await fetch(`${PAY2S_CONFIG.base_url}/payments/create`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${PAY2S_CONFIG.access_token}`,
      'X-Timestamp': timestamp,
      'X-Merchant-ID': PAY2S_CONFIG.merchant_id
    },
    body: JSON.stringify({ ...input, signature })
  })

  if (!res.ok) {
    const err = await res.json()
    throw new Error(`Pay2s create failed: ${err.message} (${err.code})`)
  }

  return res.json()
}
```

## Signature Generation (HMAC-SHA256)

```typescript
// lib/pay2s-signature.ts
import crypto from 'node:crypto'

/**
 * Generate HMAC-SHA256 signature for Pay2s requests.
 * Fields must be sorted alphabetically before hashing.
 */
export function generateSignature(
  params: Record<string, string>,
  secret_key: string
): string {
  const sorted_keys = Object.keys(params).sort()
  const raw = sorted_keys
    .filter(k => params[k] !== '' && params[k] !== undefined)
    .map(k => `${k}=${params[k]}`)
    .join('&')

  return crypto
    .createHmac('sha256', secret_key)
    .update(raw)
    .digest('hex')
}

/**
 * Verify webhook signature from Pay2s callback.
 * Uses timing-safe comparison to prevent timing attacks.
 */
export function verifyWebhookSignature(
  payload: Record<string, string>,
  received_sig: string,
  webhook_secret: string
): boolean {
  const expected = generateSignature(payload, webhook_secret)
  // timing-safe compare — prevents timing attacks
  return crypto.timingSafeEqual(
    Buffer.from(expected, 'hex'),
    Buffer.from(received_sig, 'hex')
  )
}
```

## Status Check

```typescript
export async function checkPaymentStatus(payment_id: string) {
  const timestamp = Date.now().toString()
  const signature = generateSignature(
    { merchant_id: PAY2S_CONFIG.merchant_id, payment_id, timestamp },
    PAY2S_CONFIG.secret_key
  )

  const res = await fetch(
    `${PAY2S_CONFIG.base_url}/payments/${payment_id}/status`,
    {
      headers: {
        'Authorization': `Bearer ${PAY2S_CONFIG.access_token}`,
        'X-Timestamp': timestamp,
        'X-Merchant-ID': PAY2S_CONFIG.merchant_id,
        'X-Signature': signature
      }
    }
  )
  if (!res.ok) throw new Error(`Pay2s status check failed: ${res.status}`)
  return res.json() as Promise<{
    payment_id: string
    status: 'pending' | 'paid' | 'failed' | 'expired' | 'refunded'
    paid_at?: string
    amount: number
  }>
}
```

## Webhook Handler (Next.js API Route)

```typescript
// app/api/webhooks/pay2s/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { verifyWebhookSignature } from '@/lib/pay2s-signature'

export async function POST(req: NextRequest) {
  const raw_body = await req.text()
  let payload: Record<string, string>

  try {
    payload = JSON.parse(raw_body)
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
  }

  const received_sig = req.headers.get('X-Pay2s-Signature') ?? ''

  // 1. Verify signature FIRST — reject before any processing
  if (!verifyWebhookSignature(payload, received_sig, PAY2S_CONFIG.webhook_secret)) {
    console.warn('[pay2s] Invalid webhook signature')
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 })
  }

  const { order_id, status, payment_id, amount } = payload

  // 2. Process based on status
  switch (status) {
    case 'paid':
      await fulfillOrder(order_id, { payment_id, amount: Number(amount) })
      break
    case 'failed':
    case 'expired':
      await cancelOrder(order_id, status)
      break
    default:
      // pending / other — ignore or log
  }

  // 3. Must return 200 or Pay2s will retry
  return NextResponse.json({ received: true })
}
```

## Reconciliation

```typescript
export async function reconcile(date: string) {
  // date format: YYYY-MM-DD
  const res = await fetch(
    `${PAY2S_CONFIG.base_url}/reconciliation?date=${date}&merchant_id=${PAY2S_CONFIG.merchant_id}`,
    { headers: { 'Authorization': `Bearer ${PAY2S_CONFIG.access_token}` } }
  )
  if (!res.ok) throw new Error(`Reconciliation failed: ${res.status}`)
  return res.json() as Promise<{
    date: string
    total_transactions: number
    total_amount: number
    transactions: Array<{
      payment_id: string
      order_id: string
      amount: number
      status: string
      created_at: string
    }>
  }>
}
```

## Common Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| `AUTH_001` | Invalid access token | Refresh token |
| `SIGN_001` | Signature mismatch | Check secret key + sort order |
| `ORDER_DUPLICATE` | Duplicate order_id | Use unique ID |
| `AMOUNT_INVALID` | Amount < min or non-integer | Validate before sending |
| `EXPIRED` | Payment link expired | Recreate payment |

## Security Checklist

- [ ] `PAY2S_SECRET_KEY` stored in env, never committed
- [ ] Webhook signature verified before processing
- [ ] Use `crypto.timingSafeEqual` for signature comparison
- [ ] Return HTTP 200 to Pay2s after processing (prevents retries)
- [ ] Idempotency: check if `order_id` already fulfilled before processing

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "Pay2s integration task?",
      header: "Task",
      options: [
        { label: "Create payment", description: "Initiate payment + get URL" },
        { label: "Webhook handler", description: "Handle Pay2s callbacks" },
        { label: "Status check", description: "Query payment status" },
        { label: "Reconciliation", description: "Daily transaction report" }
      ]
    },
    {
      question: "Environment?",
      header: "Env",
      options: [
        { label: "Sandbox", description: "sandbox.pay2s.vn — testing" },
        { label: "Production", description: "api.pay2s.vn — live" }
      ]
    }
  ]
})
```
