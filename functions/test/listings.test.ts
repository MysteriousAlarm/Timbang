import { ListingStore, expireListings } from '../src/listings';

function store(expiresAt: number[], now = 1000) {
  const status = expiresAt.map(() => 'active');
  const s: ListingStore & { status: string[] } = {
    status,
    now: () => now,
    activeExpiredIds: async (before, limit) =>
      expiresAt
        .map((t, i) => ({ t, i }))
        .filter(({ t, i }) => status[i] === 'active' && t < before)
        .slice(0, limit)
        .map(({ i }) => String(i)),
    markExpired: async (ids) => ids.forEach((id) => (status[Number(id)] = 'expired')),
  };
  return s;
}

test('expires only overdue active listings', async () => {
  const s = store([500, 999, 1000, 2000]);
  expect(await expireListings(s)).toBe(2);
  expect(s.status).toEqual(['expired', 'expired', 'active', 'active']);
});

test('pages through many listings', async () => {
  const s = store(new Array(25).fill(1));
  expect(await expireListings(s, 10)).toBe(25);
  expect(s.status.every((x) => x === 'expired')).toBe(true);
});

test('nothing to do', async () => {
  expect(await expireListings(store([5000]))).toBe(0);
});
