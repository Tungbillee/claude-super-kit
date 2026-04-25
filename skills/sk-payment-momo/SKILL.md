---
name: sk:payment-momo
description: "MoMo e-wallet — /create /query /refund endpoints, HMAC signature, QR + deeplink, status polling, error codes"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: payment-vn
last_updated: 2026-04-25
license: MIT
---

# sk:payment-momo — MoMo Payment Integration

## Overview

MoMo is Vietnam's leading e-wallet. Two main flows: **QR payment** (user scans) and **deeplink** (redirect to MoMo app). Both use the same `/create` API with different `requestType`.

**SECURITY RULE:** `secretKey` must never be logged or sent to client.

## Environment Config

```typescript
// config/momo.ts
export const MOMO_CONFIG = {
  partnerCode: process.env.MOMO_PARTNER_CODE!,
  accessKey:   process.env.MOMO_ACCESS_KEY!,
  secretKey:   process.env.MOMO_SECRET_KEY!,   // NEVER log this
  baseUrl: process.env.NODE_ENV === 'production'
    ? 'https://payment.momo.vn'
    : 'https://test-payment.momo.vn',
  redirectUrl: process.env.MOMO_REDIRECT_URL!,  // user redirect
  ipnUrl:      process.env.MOMO_IPN_URL!        // server callback
}

// Request types
export const MOMO_REQUEST_TYPE = {
  QR:        'captureWallet',     // QR code in MoMo app
  DEEPLINK:  'payWithATM',        // ATM/bank card via MoMo
  APP:       'payWithMoMo'        // Deeplink to MoMo app
} as const
```

## Create Payment

```typescript
// lib/momo-client.ts
import crypto from 'node:crypto'

interface CreatePaymentInput {
  order_id: string           // unique per transaction
  amount: number             // VND integer
  order_info: string         // description shown to user
  request_type?: keyof typeof MOMO_REQUEST_TYPE
  extra_data?: string        // base64 encoded custom data
}

interface MomoPaymentResponse {
  partnerCode: string
  orderId: string
  requestId: string
  amount: number
  responseTime: number
  message: string
  resultCode: number         // 0 = success
  payUrl: string             // redirect / QR URL
  deeplink?: string          // MoMo app deeplink
  qrCodeUrl?: string         // QR code image URL
}

export async function createPayment(
  input: CreatePaymentInput
): Promise<MomoPaymentResponse> {
  const request_id = `${input.order_id}_${Date.now()}`
  const request_type = MOMO_REQUEST_TYPE[input.request_type ?? 'QR']
  const extra_data = input.extra_data ?? ''

  // Signature raw string — field order is CRITICAL (MoMo specifies exact order)
  const raw_signature = [
    `accessKey=${MOMO_CONFIG.accessKey}`,
    `amount=${input.amount}`,
    `extraData=${extra_data}`,
    `ipnUrl=${MOMO_CONFIG.ipnUrl}`,
    `orderId=${input.order_id}`,
    `orderInfo=${input.order_info}`,
    `partnerCode=${MOMO_CONFIG.partnerCode}`,
    `redirectUrl=${MOMO_CONFIG.redirectUrl}`,
    `requestId=${request_id}`,
    `requestType=${request_type}`
  ].join('&')

  const signature = crypto
    .createHmac('sha256', MOMO_CONFIG.secretKey)
    .update(raw_signature)
    .digest('hex')

  const payload = {
    partnerCode: MOMO_CONFIG.partnerCode,
    accessKey:   MOMO_CONFIG.accessKey,
    requestId:   request_id,
    amount:      input.amount,
    orderId:     input.order_id,
    orderInfo:   input.order_info,
    redirectUrl: MOMO_CONFIG.redirectUrl,
    ipnUrl:      MOMO_CONFIG.ipnUrl,
    extraData:   extra_data,
    requestType: request_type,
    signature,
    lang: 'vi'
  }

  const res = await fetch(`${MOMO_CONFIG.baseUrl}/v2/gateway/api/create`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })

  const data = await res.json()
  if (data.resultCode !== 0) {
    throw new Error(`MoMo create failed: [${data.resultCode}] ${data.message}`)
  }
  return data
}
```

## Query Payment Status

```typescript
export async function queryPayment(order_id: string, request_id: string) {
  const raw_signature = [
    `accessKey=${MOMO_CONFIG.accessKey}`,
    `orderId=${order_id}`,
    `partnerCode=${MOMO_CONFIG.partnerCode}`,
    `requestId=${request_id}`
  ].join('&')

  const signature = crypto
    .createHmac('sha256', MOMO_CONFIG.secretKey)
    .update(raw_signature)
    .digest('hex')

  const res = await fetch(`${MOMO_CONFIG.baseUrl}/v2/gateway/api/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      partnerCode: MOMO_CONFIG.partnerCode,
      accessKey:   MOMO_CONFIG.accessKey,
      requestId:   request_id,
      orderId:     order_id,
      signature,
      lang: 'vi'
    })
  })

  return res.json() as Promise<{
    resultCode: number
    message: string
    amount: number
    transId: number
    payType: string    // 'qr' | 'webApp' | 'credit' | 'debit'
  }>
}
```

## Refund

```typescript
export async function refundPayment(input: {
  order_id: string
  trans_id: number    // MoMo's transId from original payment
  amount: number
  description: string
}) {
  const refund_id = `refund_${input.order_id}_${Date.now()}`

  const raw_signature = [
    `accessKey=${MOMO_CONFIG.accessKey}`,
    `amount=${input.amount}`,
    `description=${input.description}`,
    `orderId=${refund_id}`,
    `partnerCode=${MOMO_CONFIG.partnerCode}`,
    `requestId=${refund_id}`,
    `transId=${input.trans_id}`
  ].join('&')

  const signature = crypto
    .createHmac('sha256', MOMO_CONFIG.secretKey)
    .update(raw_signature)
    .digest('hex')

  const res = await fetch(`${MOMO_CONFIG.baseUrl}/v2/gateway/api/refund`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      partnerCode: MOMO_CONFIG.partnerCode,
      accessKey:   MOMO_CONFIG.accessKey,
      requestId:   refund_id,
      orderId:     refund_id,
      transId:     input.trans_id,
      amount:      input.amount,
      description: input.description,
      signature,
      lang: 'vi'
    })
  })

  return res.json()
}
```

## IPN / Callback Handler (Next.js)

```typescript
// app/api/webhooks/momo/route.ts
import { NextRequest, NextResponse } from 'next/server'
import crypto from 'node:crypto'

export async function POST(req: NextRequest) {
  const body = await req.json()
  const {
    partnerCode, orderId, requestId, amount, orderInfo,
    orderType, transId, resultCode, message, payType,
    responseTime, extraData, signature: received_sig
  } = body

  // 1. Verify signature
  const raw = [
    `accessKey=${MOMO_CONFIG.accessKey}`,
    `amount=${amount}`,
    `extraData=${extraData}`,
    `message=${message}`,
    `orderId=${orderId}`,
    `orderInfo=${orderInfo}`,
    `orderType=${orderType}`,
    `partnerCode=${partnerCode}`,
    `payType=${payType}`,
    `requestId=${requestId}`,
    `responseTime=${responseTime}`,
    `resultCode=${resultCode}`,
    `transId=${transId}`
  ].join('&')

  const expected = crypto
    .createHmac('sha256', MOMO_CONFIG.secretKey)
    .update(raw)
    .digest('hex')

  if (!crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(received_sig))) {
    return NextResponse.json({ message: 'Invalid signature' }, { status: 401 })
  }

  // 2. Process
  if (resultCode === 0) {
    await fulfillOrder(orderId, { trans_id: transId, amount, pay_type: payType })
  } else {
    await failOrder(orderId, resultCode)
  }

  return NextResponse.json({ message: 'ok' })
}
```

## Status Polling (Client-Side)

```typescript
// For cases where IPN is delayed — poll from frontend
export async function pollPaymentStatus(
  order_id: string,
  request_id: string,
  max_attempts = 10,
  interval_ms = 3000
): Promise<{ success: boolean; result_code: number }> {
  for (let i = 0; i < max_attempts; i++) {
    const result = await queryPayment(order_id, request_id)
    if (result.resultCode === 0) return { success: true, result_code: 0 }
    if (result.resultCode !== 1000) return { success: false, result_code: result.resultCode }
    // 1000 = pending, keep polling
    await new Promise(r => setTimeout(r, interval_ms))
  }
  return { success: false, result_code: 1006 } // timeout
}
```

## Result Codes

| Code | Meaning | Action |
|------|---------|--------|
| `0` | Success | Fulfill order |
| `9000` | Authorized (pre-auth) | Capture later |
| `1000` | Pending | Poll again |
| `1001` | Insufficient balance | Notify user |
| `1002` | Rejected by issuer | Notify user |
| `1003` | Cancelled | Reopen cart |
| `1004` | Amount exceeds limit | Notify user |
| `1005` | URL/token expired | Recreate payment |
| `1006` | User cancelled | Reopen cart |
| `1007` | MoMo account locked | Notify user |
| `1017` | Order already processed | Idempotency check |
| `1026` | Constrained by promotions | Notify user |

## Sandbox Info

- URL: `https://test-payment.momo.vn`
- Test credentials: request from MoMo developer portal
- Test phone: any valid VN format, use MoMo test app
- Portal: https://developers.momo.vn

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "MoMo integration task?",
      header: "Task",
      options: [
        { label: "Create payment", description: "QR or deeplink flow" },
        { label: "IPN callback", description: "Server-side webhook handler" },
        { label: "Query status", description: "Check payment status" },
        { label: "Refund", description: "Full or partial refund" }
      ]
    },
    {
      question: "Payment flow type?",
      header: "Flow",
      options: [
        { label: "QR code", description: "captureWallet — user scans" },
        { label: "App deeplink", description: "payWithMoMo — redirect to app" },
        { label: "ATM/bank card", description: "payWithATM — card payment" }
      ]
    }
  ]
})
```
