import { CalcReport, BoardResult } from '../src/confidence';
import {
  NewReport,
  PriceStore,
  importOfficialPricesHandler,
  onReportCreated,
  phNoon,
  sourceFor,
  submitPriceReportHandler,
  validPrice,
} from '../src/priceReports';

const NOW = Date.UTC(2026, 10, 3, 4, 0, 0);

class MemStore implements PriceStore {
  t = NOW;
  reports: (Omit<NewReport, 'status'> & { id: string; status: CalcReport['status'] })[] = [];
  boards = new Map<string, BoardResult & { unit: string }>();
  scores = new Map<string, { scored: number; near: number; score: number }>();
  audits: { action: string; detail: string }[] = [];
  users: Record<string, { status: string; assignedMarketIds?: string[] }> = {
    farmer: { status: 'active' },
    rep: { status: 'active', assignedMarketIds: ['bayombong-pm'] },
    rep2: { status: 'active' },
    admin: { status: 'active' },
    banned: { status: 'suspended' },
  };
  commodities: Record<string, { unit: string; active: boolean }> = {
    kamatis: { unit: 'kg', active: true },
    sitaw: { unit: 'bundle', active: true },
    old: { unit: 'kg', active: false },
  };
  markets: Record<string, { active: boolean }> = {
    'bayombong-pm': { active: true },
    'solano-pm': { active: true },
  };
  now = () => this.t;
  getCommodity = async (id: string) => this.commodities[id] ?? null;
  getMarket = async (id: string) => this.markets[id] ?? null;
  getUser = async (uid: string) => this.users[uid] ?? null;
  reportsByUserSince = async (uid: string, since: number) =>
    this.reports.filter((r) => r.reporterId === uid && r.timestamp > since);
  addReports = async (rs: NewReport[]) =>
    rs.map((r) => {
      const id = `p${this.reports.length + 1}`;
      this.reports.push({ ...r, id });
      return id;
    });
  reportsForPairSince = async (c: string, m: string, since: number) =>
    this.reports
      .filter((r) => r.commodityId === c && r.marketId === m && r.timestamp > since)
      .map((r) => ({ ...r }));
  saveBoard = async (c: string, m: string, unit: string, b: BoardResult) => {
    this.boards.set(`${c}_${m}`, { ...b, unit });
    for (const u of b.statusUpdates) this.reports.find((r) => r.id === u.id)!.status = u.status;
  };
  getBoardMedian = async (c: string, m: string) =>
    this.boards.get(`${c}_${m}`)?.medianPrice ?? null;
  hooks: { prev: number | null; next: number }[] = [];
  boardUpdated = async (_c: string, _m: string, _u: string, prev: number | null, b: BoardResult) =>
    void this.hooks.push({ prev, next: b.medianPrice });
  bumpReporterScore = async (
    uid: string,
    f: (s: number, n: number) => { scored: number; near: number; score: number },
  ) => {
    const cur = this.scores.get(uid) ?? { scored: 0, near: 0, score: 0 };
    this.scores.set(uid, f(cur.scored, cur.near));
  };
  audit = async (e: { action: string; detail: string }) => void this.audits.push(e);
}

const submit = (s: MemStore, who: { uid: string; role?: string } | undefined, data: unknown) =>
  submitPriceReportHandler(who, data, s);
const ok = { commodityId: 'kamatis', marketId: 'bayombong-pm', price: 55.5 };

describe('validPrice / sourceFor / phNoon', () => {
  test('price range and centavos', () => {
    expect(validPrice(55.5)).toBe(true);
    expect(validPrice(0.01)).toBe(true);
    expect(validPrice(0)).toBe(false);
    expect(validPrice(-5)).toBe(false);
    expect(validPrice(100001)).toBe(false);
    expect(validPrice(1.234)).toBe(false);
    expect(validPrice('50')).toBe(false);
    expect(validPrice(NaN)).toBe(false);
  });
  test('source tier from claim only', () => {
    expect(sourceFor('admin')).toBe('reporter');
    expect(sourceFor('reporter')).toBe('reporter');
    expect(sourceFor('farmer')).toBe('community');
    expect(sourceFor(undefined)).toBe('community');
    expect(sourceFor('official')).toBe('community');
  });
  test('phNoon', () => {
    expect(phNoon('2026-11-03')).toBe(Date.UTC(2026, 10, 3, 4));
    expect(phNoon('2026-02-30')).toBeNull();
    expect(phNoon('11/03/2026')).toBeNull();
  });
});

describe('submitPriceReport', () => {
  test('farmer report is community, stored with server time and unit', async () => {
    const s = new MemStore();
    await expect(submit(s, { uid: 'farmer' }, ok)).resolves.toEqual({
      id: 'p1',
      source: 'community',
    });
    expect(s.reports[0]).toMatchObject({
      unit: 'kg',
      reporterRole: 'member',
      source: 'community',
      timestamp: NOW,
      status: 'valid',
      isDemo: false,
    });
  });
  test('reporter report is verified (reporter tier)', async () => {
    const s = new MemStore();
    await expect(submit(s, { uid: 'rep', role: 'reporter' }, ok)).resolves.toMatchObject({
      source: 'reporter',
    });
  });
  test('client cannot choose its own source or extra fields', async () => {
    const s = new MemStore();
    await expect(submit(s, { uid: 'farmer' }, { ...ok, source: 'official' })).rejects.toMatchObject(
      {
        code: 'invalid-argument',
      },
    );
  });
  test.each([
    [undefined, ok, 'unauthenticated'],
    [{ uid: 'ghost' }, ok, 'failed-precondition'],
    [{ uid: 'banned' }, ok, 'permission-denied'],
    [{ uid: 'farmer' }, { ...ok, commodityId: 'old' }, 'not-found'],
    [{ uid: 'farmer' }, { ...ok, commodityId: 'nope' }, 'not-found'],
    [{ uid: 'farmer' }, { ...ok, marketId: 'nope' }, 'not-found'],
    [{ uid: 'farmer' }, { ...ok, price: 0 }, 'invalid-argument'],
    [{ uid: 'farmer' }, { ...ok, commodityId: '../x' }, 'invalid-argument'],
    [{ uid: 'rep', role: 'reporter' }, { ...ok, marketId: 'solano-pm' }, 'permission-denied'],
  ])('rejects %p %p -> %s', async (who, data, code) => {
    await expect(submit(new MemStore(), who, data)).rejects.toMatchObject({ code });
  });
  test('reporter without assignments may report anywhere; admin anywhere', async () => {
    const s = new MemStore();
    await expect(
      submit(s, { uid: 'rep2', role: 'reporter' }, { ...ok, marketId: 'solano-pm' }),
    ).resolves.toBeTruthy();
    await expect(
      submit(s, { uid: 'admin', role: 'admin' }, { ...ok, marketId: 'solano-pm' }),
    ).resolves.toBeTruthy();
  });
  test('same pair twice within 10 minutes is rejected; later is fine', async () => {
    const s = new MemStore();
    await submit(s, { uid: 'farmer' }, ok);
    await expect(submit(s, { uid: 'farmer' }, ok)).rejects.toMatchObject({
      code: 'already-exists',
    });
    await expect(
      submit(s, { uid: 'farmer' }, { ...ok, commodityId: 'sitaw' }),
    ).resolves.toBeTruthy();
    s.t += 11 * 60 * 1000;
    await expect(submit(s, { uid: 'farmer' }, ok)).resolves.toBeTruthy();
  });
  test('rate limit: 20 per hour', async () => {
    const s = new MemStore();
    for (let i = 0; i < 20; i++) {
      s.reports.push({
        ...ok,
        id: `x${i}`,
        reporterId: 'farmer',
        marketId: `m${i}`,
        timestamp: NOW - 1000,
      } as never);
    }
    await expect(submit(s, { uid: 'farmer' }, ok)).rejects.toMatchObject({
      code: 'resource-exhausted',
    });
  });
});

describe('onReportCreated', () => {
  test('recomputes the board and scores the reporter', async () => {
    const s = new MemStore();
    await submit(s, { uid: 'rep2', role: 'reporter' }, ok);
    await onReportCreated({ ...s.reports[0] }, s);
    const b = s.boards.get('kamatis_bayombong-pm')!;
    expect(b).toMatchObject({
      medianPrice: 55.5,
      confidence: 'medium',
      unit: 'kg',
      reportCount: 1,
    });
    expect(s.scores.get('rep2')).toEqual({ scored: 1, near: 1, score: 1 });
  });
  test('alert hook gets previous and new median', async () => {
    const s = new MemStore();
    await submit(s, { uid: 'farmer' }, ok);
    await onReportCreated({ ...s.reports[0] }, s);
    s.users.f2 = { status: 'active' };
    await submit(s, { uid: 'f2' }, { ...ok, price: 60.5 });
    await onReportCreated({ ...s.reports[1] }, s);
    expect(s.hooks).toEqual([
      { prev: null, next: 55.5 },
      { prev: 55.5, next: 58 },
    ]);
  });
  test('community report: low confidence, no score change', async () => {
    const s = new MemStore();
    await submit(s, { uid: 'farmer' }, ok);
    await onReportCreated({ ...s.reports[0] }, s);
    expect(s.boards.get('kamatis_bayombong-pm')!.confidence).toBe('low');
    expect(s.scores.size).toBe(0);
  });
  test('outliers are persisted on the reports', async () => {
    const s = new MemStore();
    s.users.f2 = { status: 'active' };
    s.users.f3 = { status: 'active' };
    await submit(s, { uid: 'farmer' }, ok);
    await submit(s, { uid: 'f2' }, { ...ok, price: 56 });
    await submit(s, { uid: 'f3' }, { ...ok, price: 120 });
    await onReportCreated({ ...s.reports[2] }, s);
    expect(s.reports[2].status).toBe('outlier');
    expect(s.boards.get('kamatis_bayombong-pm')!.medianPrice).toBe(55.75);
  });
  test('batch imports are skipped (the import recomputes)', async () => {
    const s = new MemStore();
    await onReportCreated({ ...ok, source: 'official', reporterId: 'admin', batchId: 'b1' }, s);
    expect(s.boards.size).toBe(0);
  });
});

describe('importOfficialPrices', () => {
  const admin = { uid: 'admin', role: 'admin' };
  test('writes official reports, recomputes each pair once, audits', async () => {
    const s = new MemStore();
    const res = await importOfficialPricesHandler(
      admin,
      {
        sourceNote: 'DA Bantay Presyo',
        rows: [
          { commodityId: 'kamatis', marketId: 'bayombong-pm', price: 60 },
          { commodityId: 'kamatis', marketId: 'bayombong-pm', price: 62, date: '2026-11-03' },
          { commodityId: 'sitaw', marketId: 'solano-pm', price: 25 },
        ],
      },
      s,
    );
    expect(res).toEqual({ written: 3, boards: 2 });
    expect(s.reports.every((r) => r.source === 'official' && r.batchId)).toBe(true);
    expect(s.boards.get('kamatis_bayombong-pm')).toMatchObject({
      medianPrice: 61,
      confidence: 'high',
    });
    expect(s.boards.get('sitaw_solano-pm')!.unit).toBe('bundle');
    expect(s.audits[0].action).toBe('import_official_prices');
  });
  test('per-row errors, nothing written', async () => {
    const s = new MemStore();
    await expect(
      importOfficialPricesHandler(
        admin,
        {
          sourceNote: 'NVAT',
          rows: [
            { commodityId: 'kamatis', marketId: 'bayombong-pm', price: 60 },
            { commodityId: 'nope', marketId: 'bayombong-pm', price: 60 },
            { commodityId: 'kamatis', marketId: 'bayombong-pm', price: 60, date: '2027-01-01' },
            { commodityId: 'kamatis', marketId: 'bayombong-pm', price: 'x' },
          ],
        },
        s,
      ),
    ).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {
        errors: [
          { row: 2, message: expect.stringContaining('commodityId') },
          { row: 3, message: expect.stringContaining('future') },
          { row: 4, message: expect.stringContaining('price') },
        ],
      },
    });
    expect(s.reports).toHaveLength(0);
  });
  test.each([
    [{ uid: 'rep', role: 'reporter' }, 'permission-denied'],
    [undefined, 'unauthenticated'],
  ])('non-admin %p rejected', async (who, code) => {
    await expect(
      importOfficialPricesHandler(who, { sourceNote: 'DA', rows: [] }, new MemStore()),
    ).rejects.toMatchObject({ code });
  });
  test('requires a source note', async () => {
    await expect(
      importOfficialPricesHandler(
        admin,
        { rows: [{ commodityId: 'kamatis', marketId: 'bayombong-pm', price: 1 }] },
        new MemStore(),
      ),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});
