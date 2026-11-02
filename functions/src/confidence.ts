import {
  AGREEMENT_THRESHOLD,
  OUTLIER_THRESHOLD,
  PRICE_WINDOW_HOURS,
  Source,
  TREND_FLAT_BAND,
} from './config';

/** Pure price-board logic (CLAUDE.md Section 8). No Firebase imports: unit tested directly. */

export type ReportStatus = 'valid' | 'outlier' | 'rejected';
export type Confidence = 'high' | 'medium' | 'low';
export type Trend = 'up' | 'down' | 'flat';

export interface CalcReport {
  id: string;
  price: number;
  source: Source;
  status: ReportStatus;
  /** Epoch milliseconds. */
  timestamp: number;
  isDemo?: boolean;
}

export interface BoardResult {
  medianPrice: number;
  confidence: Confidence;
  /** Reports used for the median (valid, in window). */
  reportCount: number;
  trend: Trend;
  previousMedian: number | null;
  latestReportAt: number;
  sources: Record<Source, number>;
  /** True if any counted report is demo data. */
  isDemo: boolean;
  /** Status changes to persist (only reports whose status actually changes). */
  statusUpdates: { id: string; status: 'valid' | 'outlier' }[];
}

export const WINDOW_MS = PRICE_WINDOW_HOURS * 60 * 60 * 1000;

export function median(values: number[]): number {
  if (values.length === 0) throw new Error('median of empty list');
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  const m = s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  return Math.round(m * 100) / 100;
}

const deviation = (price: number, m: number) => Math.abs(price - m) / m;

/**
 * Splits reports into valid and outlier around the median.
 * - Rejected reports are ignored entirely (an admin decision).
 * - Official reports are never outliers: they are the reference.
 * - If every non-official report would be an outlier, none are marked
 *   (e.g. two disagreeing reports): there is no majority to trust.
 */
export function markOutliers(reports: CalcReport[]): {
  valid: CalcReport[];
  outliers: CalcReport[];
  median: number;
} {
  const candidates = reports.filter((r) => r.status !== 'rejected');
  if (candidates.length === 0) return { valid: [], outliers: [], median: NaN };
  const first = median(candidates.map((r) => r.price));
  const outliers = candidates.filter(
    (r) => r.source !== 'official' && deviation(r.price, first) > OUTLIER_THRESHOLD,
  );
  if (outliers.length === candidates.length) {
    return { valid: candidates, outliers: [], median: first };
  }
  const valid = candidates.filter((r) => !outliers.includes(r));
  return { valid, outliers, median: median(valid.map((r) => r.price)) };
}

export function classifyConfidence(valid: CalcReport[], m: number): Confidence {
  if (valid.some((r) => r.source === 'official')) return 'high';
  const agreeing = valid.filter((r) => deviation(r.price, m) <= AGREEMENT_THRESHOLD);
  if (agreeing.length >= 3 && agreeing.some((r) => r.source === 'reporter')) return 'high';
  if (valid.some((r) => r.source === 'reporter')) return 'medium';
  return 'low';
}

export function trendOf(current: number, previous: number | null): Trend {
  if (previous === null || previous <= 0) return 'flat';
  const change = (current - previous) / previous;
  if (Math.abs(change) <= TREND_FLAT_BAND) return 'flat';
  return change > 0 ? 'up' : 'down';
}

/**
 * Computes the board entry for one commodity + market.
 * @param reports reports from the last 48 hours (any status)
 * @param now epoch ms
 * @returns null when there are no usable reports in the last 24 hours: the caller
 *          keeps the previous board entry, which the UI shows as stale with its age.
 */
export function computeBoard(reports: CalcReport[], now: number): BoardResult | null {
  const inWindow = reports.filter((r) => r.timestamp > now - WINDOW_MS && r.timestamp <= now);
  const previousDay = reports.filter(
    (r) => r.timestamp > now - 2 * WINDOW_MS && r.timestamp <= now - WINDOW_MS,
  );

  const { valid, outliers, median: m } = markOutliers(inWindow);
  if (valid.length === 0) return null;

  const prev = markOutliers(previousDay);
  const previousMedian = prev.valid.length ? prev.median : null;

  const sources: Record<Source, number> = { official: 0, reporter: 0, community: 0 };
  valid.forEach((r) => (sources[r.source] += 1));

  const statusUpdates = [
    ...valid
      .filter((r) => r.status !== 'valid')
      .map((r) => ({ id: r.id, status: 'valid' as const })),
    ...outliers
      .filter((r) => r.status !== 'outlier')
      .map((r) => ({ id: r.id, status: 'outlier' as const })),
  ];

  return {
    medianPrice: m,
    confidence: classifyConfidence(valid, m),
    reportCount: valid.length,
    trend: trendOf(m, previousMedian),
    previousMedian,
    latestReportAt: Math.max(...valid.map((r) => r.timestamp)),
    sources,
    isDemo: valid.some((r) => r.isDemo === true),
    statusUpdates,
  };
}

/** Whether a reporter's price counts as "near the median" for reporterScore. */
export function isNearMedian(price: number, m: number): boolean {
  return deviation(price, m) <= AGREEMENT_THRESHOLD;
}

/** New reporterScore after one more scored report (simple hit rate, 0..1). */
export function nextReporterScore(scored: number, near: number, hit: boolean) {
  const s = scored + 1;
  const n = near + (hit ? 1 : 0);
  return { scored: s, near: n, score: Math.round((n / s) * 1000) / 1000 };
}
