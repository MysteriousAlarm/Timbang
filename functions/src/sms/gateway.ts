import { createHmac, timingSafeEqual } from 'crypto';

/** An inbound SMS after the gateway has verified it really came from the gateway. */
export interface InboundSms {
  from: string;
  text: string;
}

/** Swappable SMS provider (Semaphore, Globe Labs, ...). Section 9. */
export interface SmsGateway {
  send(to: string, text: string): Promise<void>;
  /** Returns the message if the request is authentic, otherwise null. */
  verifyWebhook(req: {
    headers: Record<string, unknown>;
    rawBody: Buffer | string;
  }): InboundSms | null;
}

export function hmacHex(secret: string, body: Buffer | string): string {
  return createHmac('sha256', secret).update(body).digest('hex');
}

/** Constant-time HMAC check of `x-timbang-signature` over the raw body. Fails closed. */
export function verifyHmac(secret: string, body: Buffer | string, signature: unknown): boolean {
  if (!secret || typeof signature !== 'string' || !/^[0-9a-f]{64}$/i.test(signature)) return false;
  const expected = Buffer.from(hmacHex(secret, body), 'hex');
  const got = Buffer.from(signature, 'hex');
  return expected.length === got.length && timingSafeEqual(expected, got);
}

/** "+639171234567" -> "+63917***4567" for logs. Never log full numbers. */
export function maskNumber(n: string): string {
  return n.length > 7 ? `${n.slice(0, 6)}***${n.slice(-4)}` : '***';
}

/**
 * Development gateway: JSON body {from, text} signed with HMAC-SHA256 in `x-timbang-signature`.
 * Outgoing messages are kept in memory and logged (masked), never sent.
 */
export class MockSmsGateway implements SmsGateway {
  constructor(private readonly secret: string) {}
  outbox: { to: string; text: string }[] = [];

  async send(to: string, text: string): Promise<void> {
    this.outbox.push({ to, text });
    console.log(`[sms:mock] to ${maskNumber(to)}: ${text}`);
  }

  verifyWebhook(req: {
    headers: Record<string, unknown>;
    rawBody: Buffer | string;
  }): InboundSms | null {
    if (!verifyHmac(this.secret, req.rawBody, req.headers['x-timbang-signature'])) return null;
    try {
      const body = JSON.parse(req.rawBody.toString()) as Record<string, unknown>;
      if (typeof body.from !== 'string' || typeof body.text !== 'string') return null;
      if (!/^\+?\d{10,15}$/.test(body.from)) return null;
      return { from: body.from, text: body.text };
    } catch {
      return null;
    }
  }
}
