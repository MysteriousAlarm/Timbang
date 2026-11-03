import { HttpsError } from 'firebase-functions/v2/https';
import {
  DUPLICATE_REPORT_MINUTES,
  OFFICIAL_IMPORT_MAX_ROWS,
  PRICE_MAX,
  PRICE_MIN,
  REPORTS_PER_HOUR,
  Source,
} from './config';
import {
  BoardResult,
  CalcReport,
  WINDOW_MS,
  computeBoard,
  isNearMedian,
  nextReporterScore,
} from './confidence';

export interface NewReport {
  commodityId: string;
  marketId: string;
  price: number;
  unit: string;
  reporterId: string;
  reporterRole: string;
  source: Source;
  /** Epoch ms. */
  timestamp: number;
  status: 'valid';
  isDemo: boolean;
  batchId?: string;
  sourceNote?: string;
}

/** Data access used by the handlers. Implemented with Firestore in index.ts, faked in tests. */
export interface PriceStore {
  now(): number;
  getCommodity(id: string): Promise<{ unit: string; active: boolean } | null>;
  getMarket(id: string): Promise<{ active: boolean } | null>;
  getUser(uid: string): Promise<{ status: string; assignedMarketIds?: string[] } | null>;
  reportsByUserSince(
    uid: string,
    sinceMs: number,
  ): Promise<{ commodityId: string; marketId: string; timestamp: number }[]>;
  addReports(reports: NewReport[]): Promise<string[]>;
  reportsForPairSince(
    commodityId: string,
    marketId: string,
    sinceMs: number,
  ): Promise<CalcReport[]>;
  saveBoard(commodityId: string, marketId: string, unit: string, board: BoardResult): Promise<void>;
  /** Current median on the board, before this recompute (null if none). */
  getBoardMedian(commodityId: string, marketId: string): Promise<number | null>;
  /** Called after a board entry is saved (price alerts, Step 7). */
  boardUpdated?(
    commodityId: string,
    marketId: string,
    unit: string,
    prev: number | null,
    board: BoardResult,
  ): Promise<void>;
  bumpReporterScore(
    uid: string,
    update: (scored: number, near: number) => { scored: number; near: number; score: number },
  ): Promise<void>;
  audit(entry: {
    actorId: string;
    action: string;
    targetPath: string;
    detail: string;
  }): Promise<void>;
}

type Caller = { uid: string; role?: unknown } | undefined;

const ID = /^[a-z0-9][a-z0-9-]{1,48}$/;

export function validPrice(v: unknown): v is number {
  return (
    typeof v === 'number' &&
    Number.isFinite(v) &&
    v >= PRICE_MIN &&
    v <= PRICE_MAX &&
    Math.abs(v * 100 - Math.round(v * 100)) < 1e-6
  );
}

/** Source tier comes from the verified role claim, never from the client. */
export function sourceFor(role: unknown): Source {
  return role === 'reporter' || role === 'admin' ? 'reporter' : 'community';
}

/** Any signed-in user may report; reporters/admins count as verified, others as community. */
export async function submitPriceReportHandler(
  caller: Caller,
  data: unknown,
  store: PriceStore,
): Promise<{ id: string; source: Source }> {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  const d = (typeof data === 'object' && data !== null ? data : {}) as Record<string, unknown>;
  const extra = Object.keys(d).filter((k) => !['commodityId', 'marketId', 'price'].includes(k));
  if (extra.length) throw new HttpsError('invalid-argument', 'Unexpected fields.');
  const { commodityId, marketId, price } = d;
  if (typeof commodityId !== 'string' || !ID.test(commodityId)) {
    throw new HttpsError('invalid-argument', 'Invalid commodityId.');
  }
  if (typeof marketId !== 'string' || !ID.test(marketId)) {
    throw new HttpsError('invalid-argument', 'Invalid marketId.');
  }
  if (!validPrice(price)) {
    throw new HttpsError(
      'invalid-argument',
      `price must be ${PRICE_MIN}-${PRICE_MAX}, 2 decimals.`,
    );
  }

  const user = await store.getUser(caller.uid);
  if (!user) throw new HttpsError('failed-precondition', 'Create your profile first.');
  if (user.status !== 'active') throw new HttpsError('permission-denied', 'Account suspended.');

  const [commodity, market] = await Promise.all([
    store.getCommodity(commodityId),
    store.getMarket(marketId),
  ]);
  if (!commodity?.active) throw new HttpsError('not-found', 'Unknown or inactive commodity.');
  if (!market?.active) throw new HttpsError('not-found', 'Unknown or inactive market.');

  const source = sourceFor(caller.role);
  const assigned = user.assignedMarketIds ?? [];
  if (caller.role === 'reporter' && assigned.length > 0 && !assigned.includes(marketId)) {
    throw new HttpsError('permission-denied', 'You are not assigned to this market.');
  }

  // Rate limits (Section 10): per hour, and no repeats of the same pair within a few minutes.
  const now = store.now();
  const recent = await store.reportsByUserSince(caller.uid, now - 60 * 60 * 1000);
  if (recent.length >= REPORTS_PER_HOUR) {
    throw new HttpsError('resource-exhausted', 'Too many reports. Try again later.');
  }
  const dupSince = now - DUPLICATE_REPORT_MINUTES * 60 * 1000;
  if (
    recent.some(
      (r) => r.commodityId === commodityId && r.marketId === marketId && r.timestamp > dupSince,
    )
  ) {
    throw new HttpsError('already-exists', 'You just reported this. Try again later.');
  }

  const [id] = await store.addReports([
    {
      commodityId,
      marketId,
      price,
      unit: commodity.unit,
      reporterId: caller.uid,
      reporterRole: typeof caller.role === 'string' ? caller.role : 'member',
      source,
      timestamp: now,
      status: 'valid',
      isDemo: false,
    },
  ]);
  return { id, source };
}

/** Recomputes the board entry for one commodity + market. Returns the board, or null if stale. */
export async function recomputeBoard(
  commodityId: string,
  marketId: string,
  store: PriceStore,
): Promise<BoardResult | null> {
  const now = store.now();
  const reports = await store.reportsForPairSince(commodityId, marketId, now - 2 * WINDOW_MS);
  const board = computeBoard(reports, now);
  if (!board) return null;
  const commodity = await store.getCommodity(commodityId);
  const unit = commodity?.unit ?? 'kg';
  const prev = await store.getBoardMedian(commodityId, marketId);
  await store.saveBoard(commodityId, marketId, unit, board);
  if (store.boardUpdated) {
    try {
      await store.boardUpdated(commodityId, marketId, unit, prev, board);
    } catch (e) {
      console.warn('boardUpdated hook failed', (e as Error).message);
    }
  }
  return board;
}

/** Trigger body for a newly created report. */
export async function onReportCreated(
  report: {
    commodityId: string;
    marketId: string;
    price: number;
    source: Source;
    reporterId: string;
    batchId?: string;
  },
  store: PriceStore,
): Promise<void> {
  // Bulk official imports recompute once per pair themselves.
  if (report.batchId) return;
  const board = await recomputeBoard(report.commodityId, report.marketId, store);
  if (board && report.source === 'reporter') {
    const hit = isNearMedian(report.price, board.medianPrice);
    await store.bumpReporterScore(report.reporterId, (s, n) => nextReporterScore(s, n, hit));
  }
}

export interface OfficialRow {
  commodityId: string;
  marketId: string;
  price: number;
  /** YYYY-MM-DD (observation date, Philippine time). Defaults to now. */
  date?: string;
}

/** Noon Philippine time (UTC+8) on the given date, as epoch ms. */
export function phNoon(date: string): number | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!m) return null;
  const ms = Date.UTC(+m[1], +m[2] - 1, +m[3], 4, 0, 0);
  const back = new Date(ms);
  if (back.getUTCMonth() !== +m[2] - 1 || back.getUTCDate() !== +m[3]) return null;
  return ms;
}

/**
 * Admin-only: import official prices (DA / DAR / NVAT) as `official` reports.
 * All-or-nothing with per-row errors; recomputes each affected board entry once.
 */
export async function importOfficialPricesHandler(
  caller: Caller,
  data: unknown,
  store: PriceStore,
): Promise<{ written: number; boards: number }> {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (caller.role !== 'admin') throw new HttpsError('permission-denied', 'Admins only.');
  const d = (typeof data === 'object' && data !== null ? data : {}) as Record<string, unknown>;
  const note = typeof d.sourceNote === 'string' ? d.sourceNote.trim() : '';
  if (note.length < 2 || note.length > 80) {
    throw new HttpsError(
      'invalid-argument',
      'sourceNote: 2-80 characters (e.g. "DA Bantay Presyo").',
    );
  }
  if (!Array.isArray(d.rows) || d.rows.length === 0 || d.rows.length > OFFICIAL_IMPORT_MAX_ROWS) {
    throw new HttpsError('invalid-argument', `rows: 1-${OFFICIAL_IMPORT_MAX_ROWS} items.`);
  }

  const now = store.now();
  const oldest = now - 366 * 24 * 60 * 60 * 1000;
  const commodityCache = new Map<string, { unit: string; active: boolean } | null>();
  const marketCache = new Map<string, { active: boolean } | null>();
  const errors: { row: number; message: string }[] = [];
  const reports: NewReport[] = [];
  const batchId = `import-${now}-${caller.uid.slice(0, 8)}`;

  for (let i = 0; i < d.rows.length; i++) {
    const raw = d.rows[i] as Record<string, unknown>;
    try {
      if (typeof raw !== 'object' || raw === null) throw new Error('not an object');
      const { commodityId, marketId, price, date } = raw;
      if (typeof commodityId !== 'string' || !ID.test(commodityId))
        throw new Error('commodityId: invalid');
      if (typeof marketId !== 'string' || !ID.test(marketId)) throw new Error('marketId: invalid');
      if (!validPrice(price)) throw new Error(`price: ${PRICE_MIN}-${PRICE_MAX}, 2 decimals`);
      let ts = now;
      if (date !== undefined && date !== '') {
        const parsed = typeof date === 'string' ? phNoon(date) : null;
        if (parsed === null) throw new Error('date: use YYYY-MM-DD');
        if (parsed > now + 12 * 60 * 60 * 1000) throw new Error('date: in the future');
        if (parsed < oldest) throw new Error('date: older than one year');
        ts = Math.min(parsed, now);
      }
      if (!commodityCache.has(commodityId))
        commodityCache.set(commodityId, await store.getCommodity(commodityId));
      if (!marketCache.has(marketId)) marketCache.set(marketId, await store.getMarket(marketId));
      const c = commodityCache.get(commodityId);
      if (!c?.active) throw new Error(`commodityId: "${commodityId}" not found or inactive`);
      if (!marketCache.get(marketId)?.active)
        throw new Error(`marketId: "${marketId}" not found or inactive`);
      reports.push({
        commodityId,
        marketId,
        price,
        unit: c.unit,
        reporterId: caller.uid,
        reporterRole: 'admin',
        source: 'official',
        timestamp: ts,
        status: 'valid',
        isDemo: false,
        batchId,
        sourceNote: note,
      });
    } catch (e) {
      errors.push({ row: i + 1, message: (e as Error).message });
    }
  }
  if (errors.length) throw new HttpsError('invalid-argument', 'Some rows are invalid.', { errors });

  await store.addReports(reports);
  const pairs = [...new Set(reports.map((r) => `${r.commodityId}_${r.marketId}`))];
  for (const p of pairs) {
    const [c, m] = p.split('_');
    await recomputeBoard(c, m, store);
  }
  await store.audit({
    actorId: caller.uid,
    action: 'import_official_prices',
    targetPath: 'price_reports',
    detail: `${reports.length} row(s) from "${note}" (${batchId})`,
  });
  return { written: reports.length, boards: pairs.length };
}
