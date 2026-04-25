---
name: sk:payment-vnpay
description: "VNPay — checkout URL, SecureHash (SHA512), IPN handling, refunds, multi-bank, sandbox test cards"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: payment-vn
last_updated: 2026-04-25
license: MIT
---

# sk:payment-vnpay — VNPay Payment Integration

## Overview

VNPay is Vietnam's largest payment gateway. Integration flow: build checkout URL with SecureHash → redirect user → handle IPN callback → verify hash → fulfill order.

**SECURITY RULE:** `vnp_HashSecret` must never be logged or exposed to client.

## Environment Config

```typescript
// config/vnpay.ts
export const VNPAY_CONFIG = {
  tmnCode: process.env.VNPAY_TMN_CODE!,          // Merchant terminal code
  hashSecret: process.env.VNPAY_HASH_SECRET!,     // NEVER log this
  baseUrl: process.env.NODE_ENV === 'production'
    ? 'https://pay.vnpay.vn/vpcpay.html'
    : 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
  returnUrl: process.env.VNPAY_RETURN_URL!,       // User redirect after payment
  ipnUrl: process.env.VNPAY_IPN_URL!              // Server-to-server callback
}
```

## Build Checkout URL

```typescript
// lib/vnpay-client.ts
import crypto from 'node:crypto'
import { stringify } from 'qs'

interface CreateOrderInput {
  order_id: string    // unique, max 20 chars, alphanumeric
  amount: number      // VND, integer (will be multiplied ×100 per VNPay spec)
  order_desc: string  // max 255 chars
  bank_code?: string  // pre-select bank: VNBANK, INTCARD, or empty for all
  locale?: 'vn' | 'en'
  client_ip: string
}

export function buildCheckoutUrl(input: CreateOrderInput): string {
  const now = new Date()
  const create_date = formatVnDate(now)           // yyyyMMddHHmmss
  const expire_date = formatVnDate(new Date(now.getTime() + 15 * 60 * 1000))

  const params: Record<string, string> = {
    vnp_Version:     '2.1.0',
    vnp_Command:     'pay',
    vnp_TmnCode:     VNPAY_CONFIG.tmnCode,
    vnp_Amount:      (input.amount * 100).toString(), // ×100 required by VNPay
    vnp_CreateDate:  create_date,
    vnp_CurrCode:    'VND',
    vnp_IpAddr:      input.client_ip,
    vnp_Locale:      input.locale ?? 'vn',
    vnp_OrderInfo:   input.order_desc,
    vnp_OrderType:   'other',
    vnp_ReturnUrl:   VNPAY_CONFIG.returnUrl,
    vnp_TxnRef:      input.order_id,
    vnp_ExpireDate:  expire_date,
  }

  if (input.bank_code) params.vnp_BankCode = input.bank_code

  const secure_hash = generateSecureHash(params, VNPAY_CONFIG.hashSecret)
  params.vnp_SecureHash = secure_hash

  return `${VNPAY_CONFIG.baseUrl}?${stringify(params, { encode: false })}`
}

function formatVnDate(d: Date): string {
  return d.toISOString()
    .replace(/[-T:.Z]/g, '')
    .slice(0, 14)
}
```

## SecureHash Generation (SHA512)

```typescript
// lib/vnpay-signature.ts
import crypto from 'node:crypto'

/**
 * VNPay SecureHash: sort params alphabetically, exclude vnp_SecureHash,
 * join as key=value&..., then HMAC-SHA512 with hashSecret.
 */
export function generateSecureHash(
  params: Record<string, string>,
  hash_secret: string
): string {
  const sorted_keys = Object.keys(params)
    .filter(k => k !== 'vnp_SecureHash' && k !== 'vnp_SecureHashType')
    .sort()

  const raw = sorted_keys
    .map(k => `${k}=${params[k]}`)
    .join('&')

  return crypto
    .createHmac('sha512', hash_secret)
    .update(raw)
    .digest('hex')
}

/**
 * Verify SecureHash from VNPay callback (IPN or return URL).
 * Extract and remove hash from params, recalculate, compare.
 */
export function verifySecureHash(
  params: Record<string, string>,
  hash_secret: string
): boolean {
  const received = params.vnp_SecureHash
  if (!received) return false

  const cleaned = { ...params }
  delete cleaned.vnp_SecureHash
  delete cleaned.vnp_SecureHashType

  const expected = generateSecureHash(cleaned, hash_secret)
  return crypto.timingSafeEqual(
    Buffer.from(expected),
    Buffer.from(received)
  )
}
```

## IPN Handler (Next.js)

```typescript
// app/api/webhooks/vnpay/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { verifySecureHash } from '@/lib/vnpay-signature'

// VNPay IPN: server-to-server, GET request with query params
export async function GET(req: NextRequest) {
  const params = Object.fromEntries(req.nextUrl.searchParams)

  // 1. Verify hash FIRST
  if (!verifySecureHash(params, VNPAY_CONFIG.hashSecret)) {
    return NextResponse.json({ RspCode: '97', Message: 'Invalid signature' })
  }

  const {
    vnp_TxnRef: order_id,
    vnp_ResponseCode: response_code,
    vnp_Amount: raw_amount,
    vnp_TransactionNo: vnpay_txn_id
  } = params

  const amount = Number(raw_amount) / 100  // divide back from ×100

  // 2. Check order exists
  const order = await findOrder(order_id)
  if (!order) {
    return NextResponse.json({ RspCode: '01', Message: 'Order not found' })
  }

  // 3. Check amount matches
  if (order.amount !== amount) {
    return NextResponse.json({ RspCode: '04', Message: 'Invalid amount' })
  }

  // 4. Check not already processed (idempotency)
  if (order.status === 'paid') {
    return NextResponse.json({ RspCode: '02', Message: 'Order already confirmed' })
  }

  // 5. Process result
  if (response_code === '00') {
    await fulfillOrder(order_id, vnpay_txn_id)
  } else {
    await failOrder(order_id, response_code)
  }

  // VNPay requires this exact response format
  return NextResponse.json({ RspCode: '00', Message: 'Confirm success' })
}
```

## Return URL Handler

```typescript
// app/payment/return/page.tsx (or API route)
// User redirect — verify params before showing success/fail UI

export async function verifyReturnParams(search_params: URLSearchParams) {
  const params = Object.fromEntries(search_params)
  const is_valid = verifySecureHash(params, VNPAY_CONFIG.hashSecret)
  const is_success = params.vnp_ResponseCode === '00'

  return {
    is_valid,
    is_success,
    order_id: params.vnp_TxnRef,
    amount: Number(params.vnp_Amount) / 100,
    bank_code: params.vnp_BankCode,
    transaction_id: params.vnp_TransactionNo
  }
}
```

## Refund API

```typescript
export async function refundPayment(input: {
  order_id: string
  txn_ref: string       // original vnp_TransactionNo
  amount: number        // VND
  reason: string
}) {
  const params = {
    vnp_RequestId: `refund_${Date.now()}`,
    vnp_Version:   '2.1.0',
    vnp_Command:   'refund',
    vnp_TmnCode:   VNPAY_CONFIG.tmnCode,
    vnp_TransactionType: '02',   // 02 = partial, 03 = full
    vnp_TxnRef:    input.order_id,
    vnp_Amount:    (input.amount * 100).toString(),
    vnp_OrderInfo: input.reason,
    vnp_TransactionNo: input.txn_ref,
    vnp_TransactionDate: formatVnDate(new Date()),
    vnp_CreateBy:  'system',
    vnp_CreateDate: formatVnDate(new Date()),
    vnp_IpAddr:    '127.0.0.1'
  }

  const hash = generateSecureHash(params, VNPAY_CONFIG.hashSecret)

  const res = await fetch('https://merchant.vnpay.vn/merchant_webapi/api/transaction', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...params, vnp_SecureHash: hash })
  })

  return res.json()
}
```

## Response Codes

| Code | Meaning |
|------|---------|
| `00` | Success |
| `07` | Suspicious transaction |
| `09` | Card not registered for internet banking |
| `10` | Identity verification failed (3 times) |
| `11` | Payment timeout |
| `12` | Card locked |
| `13` | Wrong OTP |
| `24` | User cancelled |
| `51` | Insufficient balance |
| `65` | Daily limit exceeded |
| `75` | Bank maintenance |
| `79` | Wrong PIN too many times |
| `99` | Unknown error |

## Sandbox Test Cards

| Bank | Card number | Name | Date | OTP |
|------|------------|------|------|-----|
| NCB | 9704198526191432198 | NGUYEN VAN A | 07/15 | 123456 |
| NCB (intl) | 9704195798459170488 | NGUYEN VAN A | 07/15 | 123456 |

Sandbox URL: `https://sandbox.vnpayment.vn/paymentv2/vpcpay.html`

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "VNPay integration task?",
      header: "Task",
      options: [
        { label: "Checkout URL", description: "Build payment URL + redirect" },
        { label: "IPN handler", description: "Server callback verification" },
        { label: "Return URL", description: "User redirect after payment" },
        { label: "Refund", description: "Full or partial refund" }
      ]
    },
    {
      question: "Framework?",
      header: "Framework",
      options: [
        { label: "Next.js", description: "App Router API routes" },
        { label: "Nuxt 3", description: "Server routes" },
        { label: "Express / Fastify", description: "Node.js server" }
      ]
    }
  ]
})
```
