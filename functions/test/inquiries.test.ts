import { InquiryStore, NewInquiry, sendInquiryHandler } from '../src/inquiries';
import { Notifier, RecordingNotifier } from '../src/notify';

const NOW = Date.UTC(2026, 10, 3, 4);

class Mem implements InquiryStore {
  t = NOW;
  inquiries: (NewInquiry & { id: string })[] = [];
  users: Record<string, { name: string; phone: string; status: string }> = {
    buyer: { name: 'Bea', phone: '+639170000001', status: 'active' },
    farmer: { name: 'Juan', phone: '+639170000002', status: 'active' },
    banned: { name: 'X', phone: '+639170000003', status: 'suspended' },
  };
  listings: Record<
    string,
    { farmerId: string; commodityId: string; status: string; expiresAt: number }
  > = {
    L1: {
      farmerId: 'farmer',
      commodityId: 'kamatis',
      status: 'active',
      expiresAt: NOW + 86400_000,
    },
    L2: { farmerId: 'farmer', commodityId: 'kamatis', status: 'sold', expiresAt: NOW + 86400_000 },
    L3: { farmerId: 'farmer', commodityId: 'kamatis', status: 'active', expiresAt: NOW - 1 },
  };
  now = () => this.t;
  getUser = async (u: string) => this.users[u] ?? null;
  getListing = async (id: string) => this.listings[id] ?? null;
  getCommodityName = async () => 'Kamatis';
  inquiriesByBuyerSince = async (uid: string, since: number) =>
    this.inquiries.filter((i) => i.buyerId === uid && i.createdAt > since);
  addInquiry = async (i: NewInquiry) => {
    const id = `q${this.inquiries.length + 1}`;
    this.inquiries.push({ ...i, id });
    return id;
  };
}

const msg = { listingId: 'L1', message: '  Available pa po ba?  ' };

test('creates the inquiry with buyer contact and notifies the farmer', async () => {
  const s = new Mem();
  const n = new RecordingNotifier();
  await expect(sendInquiryHandler({ uid: 'buyer' }, msg, s, n)).resolves.toEqual({ id: 'q1' });
  expect(s.inquiries[0]).toMatchObject({
    farmerId: 'farmer',
    buyerName: 'Bea',
    buyerPhone: '+639170000001',
    message: 'Available pa po ba?',
    status: 'new',
    commodityId: 'kamatis',
  });
  expect(n.sent).toHaveLength(1);
  expect(n.sent[0].uid).toBe('farmer');
  expect(n.sent[0].msg.body).toContain('Bea');
  expect(n.sent[0].msg.body).not.toContain('+63');
});

test.each([
  [undefined, msg, 'unauthenticated'],
  [{ uid: 'ghost' }, msg, 'failed-precondition'],
  [{ uid: 'banned' }, msg, 'permission-denied'],
  [{ uid: 'farmer' }, msg, 'failed-precondition'],
  [{ uid: 'buyer' }, { ...msg, listingId: 'L2' }, 'not-found'],
  [{ uid: 'buyer' }, { ...msg, listingId: 'L3' }, 'not-found'],
  [{ uid: 'buyer' }, { ...msg, listingId: 'nope' }, 'not-found'],
  [{ uid: 'buyer' }, { ...msg, message: '   ' }, 'invalid-argument'],
  [{ uid: 'buyer' }, { ...msg, message: 'x'.repeat(501) }, 'invalid-argument'],
  [{ uid: 'buyer' }, { ...msg, farmerId: 'x' }, 'invalid-argument'],
])('rejects %p %p -> %s', async (who, data, code) => {
  await expect(
    sendInquiryHandler(who, data, new Mem(), new RecordingNotifier()),
  ).rejects.toMatchObject({ code });
});

test('one inquiry per listing per 6 hours, 10 per hour', async () => {
  const s = new Mem();
  const n = new RecordingNotifier();
  await sendInquiryHandler({ uid: 'buyer' }, msg, s, n);
  await expect(sendInquiryHandler({ uid: 'buyer' }, msg, s, n)).rejects.toMatchObject({
    code: 'already-exists',
  });
  for (let i = 0; i < 10; i++) {
    s.listings[`X${i}`] = { ...s.listings.L1 };
  }
  for (let i = 0; i < 9; i++)
    await sendInquiryHandler({ uid: 'buyer' }, { ...msg, listingId: `X${i}` }, s, n);
  await expect(
    sendInquiryHandler({ uid: 'buyer' }, { ...msg, listingId: 'X9' }, s, n),
  ).rejects.toMatchObject({
    code: 'resource-exhausted',
  });
});

test('a push failure does not fail the inquiry', async () => {
  const failing: Notifier = { sendToUser: async () => Promise.reject(new Error('fcm down')) };
  const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
  await expect(sendInquiryHandler({ uid: 'buyer' }, msg, new Mem(), failing)).resolves.toEqual({
    id: 'q1',
  });
  warn.mockRestore();
});
