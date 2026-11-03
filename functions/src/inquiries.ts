import { HttpsError } from 'firebase-functions/v2/https';
import { INQUIRIES_PER_HOUR, INQUIRY_MESSAGE_MAX, INQUIRY_REPEAT_HOURS } from './config';
import { Notifier } from './notify';

export interface InquiryStore {
  now(): number;
  getUser(uid: string): Promise<{ name: string; phone: string; status: string } | null>;
  getListing(id: string): Promise<{
    farmerId: string;
    commodityId: string;
    status: string;
    expiresAt: number;
  } | null>;
  getCommodityName(id: string): Promise<string | null>;
  inquiriesByBuyerSince(
    uid: string,
    sinceMs: number,
  ): Promise<{ listingId: string; createdAt: number }[]>;
  addInquiry(i: NewInquiry): Promise<string>;
}

export interface NewInquiry {
  listingId: string;
  farmerId: string;
  buyerId: string;
  buyerName: string;
  buyerPhone: string;
  commodityId: string;
  message: string;
  status: 'new';
  createdAt: number;
}

const ID = /^[A-Za-z0-9_-]{1,128}$/;

/**
 * Any signed-in, active user can ask about a live listing (not their own).
 * Rate limited; notifies the farmer by push. No chat: follow-up is by call/text.
 */
export async function sendInquiryHandler(
  caller: { uid: string } | undefined,
  data: unknown,
  store: InquiryStore,
  notifier: Notifier,
): Promise<{ id: string }> {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  const d = (typeof data === 'object' && data !== null ? data : {}) as Record<string, unknown>;
  if (Object.keys(d).some((k) => k !== 'listingId' && k !== 'message')) {
    throw new HttpsError('invalid-argument', 'Unexpected fields.');
  }
  if (typeof d.listingId !== 'string' || !ID.test(d.listingId)) {
    throw new HttpsError('invalid-argument', 'Invalid listingId.');
  }
  const message = typeof d.message === 'string' ? d.message.trim() : '';
  if (message.length < 1 || message.length > INQUIRY_MESSAGE_MAX) {
    throw new HttpsError('invalid-argument', `message: 1-${INQUIRY_MESSAGE_MAX} characters.`);
  }

  const buyer = await store.getUser(caller.uid);
  if (!buyer) throw new HttpsError('failed-precondition', 'Create your profile first.');
  if (buyer.status !== 'active') throw new HttpsError('permission-denied', 'Account suspended.');

  const now = store.now();
  const listing = await store.getListing(d.listingId);
  if (!listing || listing.status !== 'active' || listing.expiresAt <= now) {
    throw new HttpsError('not-found', 'This listing is no longer available.');
  }
  if (listing.farmerId === caller.uid) {
    throw new HttpsError('failed-precondition', 'You cannot ask about your own listing.');
  }

  const recent = await store.inquiriesByBuyerSince(
    caller.uid,
    now - INQUIRY_REPEAT_HOURS * 3600_000,
  );
  if (recent.filter((r) => r.createdAt > now - 3600_000).length >= INQUIRIES_PER_HOUR) {
    throw new HttpsError('resource-exhausted', 'Too many inquiries. Try again later.');
  }
  if (recent.some((r) => r.listingId === d.listingId)) {
    throw new HttpsError('already-exists', 'You already asked about this listing.');
  }

  const id = await store.addInquiry({
    listingId: d.listingId,
    farmerId: listing.farmerId,
    buyerId: caller.uid,
    buyerName: buyer.name,
    buyerPhone: buyer.phone,
    commodityId: listing.commodityId,
    message,
    status: 'new',
    createdAt: now,
  });

  const commodity = (await store.getCommodityName(listing.commodityId)) ?? listing.commodityId;
  // Push failures must never fail the inquiry: the farmer still sees it in the inbox.
  try {
    await notifier.sendToUser(listing.farmerId, {
      title: 'TIMBANG: May bagong tanong',
      body: `${buyer.name} ay nagtanong tungkol sa iyong ${commodity}.`,
      data: { type: 'inquiry', inquiryId: id, listingId: d.listingId },
    });
  } catch (e) {
    console.warn('push failed', (e as Error).message);
  }
  return { id };
}
