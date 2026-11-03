import { createHash } from 'crypto';
import { SMS_MAX_INBOUND, SMS_PER_HOUR } from '../config';
import { SmsGateway, maskNumber } from './gateway';
import { SmsBoard, SmsCommodity, SmsMarket, buildReply, parseSms } from './query';

export interface SmsStore {
  now(): number;
  commodities(): Promise<SmsCommodity[]>;
  markets(): Promise<SmsMarket[]>;
  boardsFor(commodityId: string): Promise<SmsBoard[]>;
  /** Atomically counts this message for the number's hourly window; returns the new count. */
  hit(key: string, windowMs: number): Promise<number>;
}

/** Rate-limit key: a hash, so phone numbers are never stored. */
export function numberKey(from: string): string {
  return createHash('sha256').update(`timbang-sms:${from}`).digest('hex').slice(0, 40);
}

/** Answers one inbound SMS. Returns the reply text, or null when rate-limited (no reply). */
export async function handleSms(
  msg: { from: string; text: string },
  store: SmsStore,
  gateway: SmsGateway,
  opts: { rateLimit?: boolean } = {},
): Promise<string | null> {
  if (opts.rateLimit !== false) {
    const count = await store.hit(numberKey(msg.from), 3600_000);
    if (count > SMS_PER_HOUR) {
      console.warn(`[sms] rate limited ${maskNumber(msg.from)}`);
      return null;
    }
  }
  const text = msg.text.slice(0, SMS_MAX_INBOUND);
  const commodities = await store.commodities();
  const parsed = parseSms(text, commodities);
  const markets = await store.markets();
  const boards = parsed.kind === 'query' ? await store.boardsFor(parsed.commodity.id) : [];
  const reply = buildReply(parsed, { markets, boards, now: store.now() });
  await gateway.send(msg.from, reply);
  return reply;
}
