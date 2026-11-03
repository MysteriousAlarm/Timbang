import { HttpsError } from 'firebase-functions/v2/https';

/** Admin moderation, reporter management and pilot metrics (Step 8). */
type Caller = { uid: string; role?: unknown } | undefined;
type Audit = (e: {
  actorId: string;
  action: string;
  targetPath: string;
  detail: string;
}) => Promise<void>;

export function requireAdmin(caller: Caller) {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (caller.role !== 'admin') throw new HttpsError('permission-denied', 'Admins only.');
  return caller;
}

function obj(data: unknown): Record<string, unknown> {
  return (typeof data === 'object' && data !== null && !Array.isArray(data) ? data : {}) as Record<
    string,
    unknown
  >;
}
const ID = /^[A-Za-z0-9_-]{1,128}$/;
function id(v: unknown, field: string): string {
  if (typeof v !== 'string' || !ID.test(v))
    throw new HttpsError('invalid-argument', `Invalid ${field}.`);
  return v;
}
function reason(v: unknown): string {
  const r = typeof v === 'string' ? v.trim() : '';
  if (r.length < 3 || r.length > 200)
    throw new HttpsError('invalid-argument', 'reason: 3-200 characters.');
  return r;
}

export interface AdminStore {
  userExists(uid: string): Promise<{ role?: string } | null>;
  setUserStatus(uid: string, status: 'active' | 'suspended'): Promise<void>;
  setAssignedMarkets(uid: string, marketIds: string[]): Promise<void>;
  marketsExist(ids: string[]): Promise<boolean>;
  getReport(id: string): Promise<{ commodityId: string; marketId: string; status: string } | null>;
  setReportStatus(id: string, status: 'valid' | 'rejected', reason: string): Promise<void>;
  recompute(commodityId: string, marketId: string): Promise<void>;
  getListing(id: string): Promise<{ status: string } | null>;
  removeListing(id: string, reason: string): Promise<void>;
  getAbuseReport(id: string): Promise<{ status: string } | null>;
  resolveAbuseReport(id: string, resolution: 'resolved' | 'dismissed', note: string): Promise<void>;
  audit: Audit;
}

export async function setUserStatusHandler(caller: Caller, data: unknown, s: AdminStore) {
  const admin = requireAdmin(caller);
  const d = obj(data);
  const uid = id(d.uid, 'uid');
  if (d.status !== 'active' && d.status !== 'suspended') {
    throw new HttpsError('invalid-argument', 'status must be active or suspended.');
  }
  if (uid === admin.uid)
    throw new HttpsError('failed-precondition', 'You cannot suspend yourself.');
  if (!(await s.userExists(uid))) throw new HttpsError('not-found', 'User not found.');
  await s.setUserStatus(uid, d.status);
  await s.audit({
    actorId: admin.uid,
    action: 'set_user_status',
    targetPath: `users/${uid}`,
    detail: d.status,
  });
  return { uid, status: d.status };
}

export async function setReporterMarketsHandler(caller: Caller, data: unknown, s: AdminStore) {
  const admin = requireAdmin(caller);
  const d = obj(data);
  const uid = id(d.uid, 'uid');
  if (!Array.isArray(d.marketIds) || d.marketIds.length > 20) {
    throw new HttpsError('invalid-argument', 'marketIds: up to 20.');
  }
  const ids = [...new Set(d.marketIds.map((m) => id(m, 'marketId')))];
  const user = await s.userExists(uid);
  if (!user) throw new HttpsError('not-found', 'User not found.');
  if (user.role !== 'reporter')
    throw new HttpsError('failed-precondition', 'User is not a reporter.');
  if (ids.length && !(await s.marketsExist(ids)))
    throw new HttpsError('not-found', 'Unknown market.');
  await s.setAssignedMarkets(uid, ids);
  await s.audit({
    actorId: admin.uid,
    action: 'set_reporter_markets',
    targetPath: `users/${uid}`,
    detail: ids.join(', ') || '(any market)',
  });
  return { uid, marketIds: ids };
}

/** Reject a price report (excluded from the median) or restore it; recomputes the board. */
export async function moderateReportHandler(caller: Caller, data: unknown, s: AdminStore) {
  const admin = requireAdmin(caller);
  const d = obj(data);
  const reportId = id(d.reportId, 'reportId');
  if (d.action !== 'reject' && d.action !== 'restore') {
    throw new HttpsError('invalid-argument', 'action must be reject or restore.');
  }
  const why = reason(d.reason);
  const r = await s.getReport(reportId);
  if (!r) throw new HttpsError('not-found', 'Report not found.');
  const status = d.action === 'reject' ? 'rejected' : 'valid';
  await s.setReportStatus(reportId, status, why);
  await s.recompute(r.commodityId, r.marketId);
  await s.audit({
    actorId: admin.uid,
    action: `${d.action}_price_report`,
    targetPath: `price_reports/${reportId}`,
    detail: why,
  });
  return { reportId, status };
}

export async function moderateListingHandler(caller: Caller, data: unknown, s: AdminStore) {
  const admin = requireAdmin(caller);
  const d = obj(data);
  const listingId = id(d.listingId, 'listingId');
  const why = reason(d.reason);
  if (!(await s.getListing(listingId))) throw new HttpsError('not-found', 'Listing not found.');
  await s.removeListing(listingId, why);
  await s.audit({
    actorId: admin.uid,
    action: 'remove_listing',
    targetPath: `listings/${listingId}`,
    detail: why,
  });
  return { listingId, status: 'removed' };
}

export async function resolveAbuseReportHandler(caller: Caller, data: unknown, s: AdminStore) {
  const admin = requireAdmin(caller);
  const d = obj(data);
  const reportId = id(d.id, 'id');
  if (d.resolution !== 'resolved' && d.resolution !== 'dismissed') {
    throw new HttpsError('invalid-argument', 'resolution must be resolved or dismissed.');
  }
  const note = typeof d.note === 'string' ? d.note.trim().slice(0, 200) : '';
  const a = await s.getAbuseReport(reportId);
  if (!a) throw new HttpsError('not-found', 'Abuse report not found.');
  await s.resolveAbuseReport(reportId, d.resolution, note);
  await s.audit({
    actorId: admin.uid,
    action: `abuse_${d.resolution}`,
    targetPath: `abuse_reports/${reportId}`,
    detail: note || d.resolution,
  });
  return { id: reportId, status: d.resolution };
}

// ---------- pilot metrics (Section 12) ----------

export interface MetricsInput {
  now: number;
  boards: { marketId: string; latestReportAt: number }[];
  markets: { id: string; name: string }[];
  farmersTotal: number;
  activeFarmerIds30d: string[];
  listings30d: number;
  inquiries30d: number;
  reports7d: { source: string }[];
  usersByRole: Record<string, number>;
}

function medianOf(xs: number[]): number | null {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

const round1 = (v: number | null) => (v === null ? null : Math.round(v * 10) / 10);

/** Pure aggregation, unit tested. */
export function computeMetrics(i: MetricsInput) {
  const ageH = (t: number) => (i.now - t) / 3600_000;
  const perMarket = i.markets
    .map((m) => {
      const ages = i.boards.filter((b) => b.marketId === m.id).map((b) => ageH(b.latestReportAt));
      return {
        marketId: m.id,
        name: m.name,
        entries: ages.length,
        medianAgeHours: round1(medianOf(ages)),
        freshShare: ages.length
          ? round1((ages.filter((a) => a <= 24).length / ages.length) * 100)
          : null,
      };
    })
    .filter((m) => m.entries > 0)
    .sort((a, b) => b.entries - a.entries);
  const sources: Record<string, number> = { official: 0, reporter: 0, community: 0 };
  i.reports7d.forEach((r) => (sources[r.source] = (sources[r.source] ?? 0) + 1));
  return {
    generatedAt: i.now,
    medianPriceAgeHours: round1(medianOf(i.boards.map((b) => ageH(b.latestReportAt)))),
    perMarket,
    farmersTotal: i.farmersTotal,
    activeFarmers30d: new Set(i.activeFarmerIds30d).size,
    listings30d: i.listings30d,
    inquiries30d: i.inquiries30d,
    inquiriesPerListing: i.listings30d ? round1(i.inquiries30d / i.listings30d) : null,
    reports7d: sources,
    usersByRole: i.usersByRole,
  };
}
