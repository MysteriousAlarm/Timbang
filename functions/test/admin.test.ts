import {
  AdminStore,
  computeMetrics,
  moderateListingHandler,
  moderateReportHandler,
  resolveAbuseReportHandler,
  setReporterMarketsHandler,
  setUserStatusHandler,
} from '../src/admin';

const admin = { uid: 'admin', role: 'admin' };

function fake() {
  const log: string[] = [];
  const s: AdminStore = {
    userExists: async (uid) =>
      uid === 'u1'
        ? { role: 'farmer' }
        : uid === 'rep'
          ? { role: 'reporter' }
          : uid === 'admin'
            ? { role: 'admin' }
            : null,
    setUserStatus: async (uid, st) => void log.push(`status:${uid}:${st}`),
    setAssignedMarkets: async (uid, ids) => void log.push(`markets:${uid}:${ids.join('|')}`),
    marketsExist: async (ids) => ids.every((x) => x.startsWith('m')),
    getReport: async (id) =>
      id === 'r1' ? { commodityId: 'k', marketId: 'm1', status: 'outlier' } : null,
    setReportStatus: async (id, st) => void log.push(`report:${id}:${st}`),
    recompute: async (c, m) => void log.push(`recompute:${c}:${m}`),
    getListing: async (id) => (id === 'L1' ? { status: 'active' } : null),
    removeListing: async (id) => void log.push(`remove:${id}`),
    getAbuseReport: async (id) => (id === 'a1' ? { status: 'open' } : null),
    resolveAbuseReport: async (id, r) => void log.push(`abuse:${id}:${r}`),
    audit: async (e) => void log.push(`audit:${e.action}`),
  };
  return { s, log };
}

describe('admin-only', () => {
  const calls: [string, (c: never, d: unknown, s: AdminStore) => Promise<unknown>, unknown][] = [
    ['status', setUserStatusHandler as never, { uid: 'u1', status: 'suspended' }],
    ['markets', setReporterMarketsHandler as never, { uid: 'rep', marketIds: ['m1'] }],
    [
      'report',
      moderateReportHandler as never,
      { reportId: 'r1', action: 'reject', reason: 'mali' },
    ],
    ['listing', moderateListingHandler as never, { listingId: 'L1', reason: 'scam' }],
    ['abuse', resolveAbuseReportHandler as never, { id: 'a1', resolution: 'resolved' }],
  ];
  test.each(calls)('%s rejects non-admins', async (_n, fn, data) => {
    const { s, log } = fake();
    await expect(fn({ uid: 'x', role: 'reporter' } as never, data, s)).rejects.toMatchObject({
      code: 'permission-denied',
    });
    await expect(fn(undefined as never, data, s)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
    expect(log).toHaveLength(0);
  });
  test.each(calls)('%s works for admins and is audited', async (_n, fn, data) => {
    const { s, log } = fake();
    await fn(admin as never, data, s);
    expect(log.some((l) => l.startsWith('audit:'))).toBe(true);
  });
});

test('suspend: not yourself, user must exist, valid status', async () => {
  const { s } = fake();
  await expect(
    setUserStatusHandler(admin, { uid: 'admin', status: 'suspended' }, s),
  ).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(
    setUserStatusHandler(admin, { uid: 'ghost', status: 'suspended' }, s),
  ).rejects.toMatchObject({ code: 'not-found' });
  await expect(
    setUserStatusHandler(admin, { uid: 'u1', status: 'deleted' }, s),
  ).rejects.toMatchObject({ code: 'invalid-argument' });
});

test('reporter markets: only for reporters, known markets, deduped', async () => {
  const { s, log } = fake();
  await expect(
    setReporterMarketsHandler(admin, { uid: 'u1', marketIds: ['m1'] }, s),
  ).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(
    setReporterMarketsHandler(admin, { uid: 'rep', marketIds: ['x1'] }, s),
  ).rejects.toMatchObject({ code: 'not-found' });
  await setReporterMarketsHandler(admin, { uid: 'rep', marketIds: ['m1', 'm1', 'm2'] }, s);
  expect(log).toContain('markets:rep:m1|m2');
});

test('rejecting a report recomputes its board', async () => {
  const { s, log } = fake();
  await moderateReportHandler(
    admin,
    { reportId: 'r1', action: 'reject', reason: 'Maling presyo' },
    s,
  );
  expect(log.slice(0, 2)).toEqual(['report:r1:rejected', 'recompute:k:m1']);
  await expect(
    moderateReportHandler(admin, { reportId: 'r1', action: 'reject', reason: 'x' }, s),
  ).rejects.toMatchObject({ code: 'invalid-argument' });
});

test('computeMetrics', () => {
  const now = 100 * 3600_000;
  const m = computeMetrics({
    now,
    boards: [
      { marketId: 'm1', latestReportAt: now - 2 * 3600_000 },
      { marketId: 'm1', latestReportAt: now - 4 * 3600_000 },
      { marketId: 'm1', latestReportAt: now - 30 * 3600_000 },
      { marketId: 'm2', latestReportAt: now - 10 * 3600_000 },
    ],
    markets: [
      { id: 'm1', name: 'Bayombong' },
      { id: 'm2', name: 'Solano' },
      { id: 'm3', name: 'Empty' },
    ],
    farmersTotal: 12,
    activeFarmerIds30d: ['a', 'b', 'a'],
    listings30d: 4,
    inquiries30d: 10,
    reports7d: [{ source: 'reporter' }, { source: 'community' }, { source: 'community' }],
    usersByRole: { farmer: 12, buyer: 5 },
  });
  expect(m.medianPriceAgeHours).toBe(7);
  expect(m.perMarket).toEqual([
    { marketId: 'm1', name: 'Bayombong', entries: 3, medianAgeHours: 4, freshShare: 66.7 },
    { marketId: 'm2', name: 'Solano', entries: 1, medianAgeHours: 10, freshShare: 100 },
  ]);
  expect(m.activeFarmers30d).toBe(2);
  expect(m.inquiriesPerListing).toBe(2.5);
  expect(m.reports7d).toEqual({ official: 0, reporter: 1, community: 2 });
});
