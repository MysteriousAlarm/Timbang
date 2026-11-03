import {
  CalcReport,
  classifyConfidence,
  computeBoard,
  isNearMedian,
  markOutliers,
  median,
  nextReporterScore,
  trendOf,
} from '../src/confidence';

const NOW = Date.UTC(2026, 10, 3, 4, 0, 0);
const H = 60 * 60 * 1000;
let n = 0;
function r(
  price: number,
  source: CalcReport['source'] = 'reporter',
  extra: Partial<CalcReport> = {},
) {
  n += 1;
  return {
    id: `r${n}`,
    price,
    source,
    status: 'valid',
    timestamp: NOW - H,
    ...extra,
  } as CalcReport;
}

describe('median', () => {
  test('odd, even, unsorted, rounding to centavos', () => {
    expect(median([30])).toBe(30);
    expect(median([40, 10, 30])).toBe(30);
    expect(median([10, 20, 30, 40])).toBe(25);
    expect(median([10, 10.005])).toBe(10);
  });
  test('never the mean', () => {
    expect(median([10, 11, 12, 100])).toBe(11.5);
  });
});

describe('markOutliers (30% rule)', () => {
  test('marks reports more than 30% from the median and recomputes', () => {
    const a = r(50),
      b = r(52),
      c = r(48),
      d = r(90);
    const res = markOutliers([a, b, c, d]);
    expect(res.outliers.map((x) => x.id)).toEqual([d.id]);
    expect(res.median).toBe(50);
  });
  test('exactly 30% is kept', () => {
    const res = markOutliers([r(100), r(100), r(130)]);
    expect(res.outliers).toHaveLength(0);
  });
  test('official reports are never outliers', () => {
    const off = r(200, 'official');
    const res = markOutliers([r(100), r(100), r(100), off]);
    expect(res.outliers).toHaveLength(0);
    expect(res.valid).toContain(off);
  });
  test('if all would be outliers, none are marked', () => {
    const res = markOutliers([r(10), r(20)]);
    expect(res.outliers).toHaveLength(0);
    expect(res.median).toBe(15);
  });
  test('rejected reports are ignored', () => {
    const res = markOutliers([r(50), r(50), r(1000, 'reporter', { status: 'rejected' })]);
    expect(res.valid).toHaveLength(2);
    expect(res.outliers).toHaveLength(0);
  });
  test('a previous outlier becomes valid again when data shifts', () => {
    const old = r(80, 'community', { status: 'outlier' });
    const res = markOutliers([old, r(78), r(82)]);
    expect(res.valid).toContain(old);
  });
});

describe('classifyConfidence', () => {
  test('high: any official report', () => {
    expect(classifyConfidence([r(50, 'official')], 50)).toBe('high');
    expect(classifyConfidence([r(50, 'official'), r(70, 'community')], 50)).toBe('high');
  });
  test('high: 3+ agreeing (within 15%) including a verified reporter', () => {
    expect(
      classifyConfidence([r(50, 'reporter'), r(55, 'community'), r(46, 'community')], 50),
    ).toBe('high');
  });
  test('not high: 3 agreeing community reports without a verified reporter', () => {
    expect(
      classifyConfidence([r(50, 'community'), r(51, 'community'), r(49, 'community')], 50),
    ).toBe('low');
  });
  test('not high: 3 reports but only 2 agree within 15%', () => {
    expect(classifyConfidence([r(50, 'reporter'), r(52, 'reporter'), r(60, 'community')], 52)).toBe(
      'medium',
    );
  });
  test('medium: 1 or 2 verified reporter reports', () => {
    expect(classifyConfidence([r(50, 'reporter')], 50)).toBe('medium');
    expect(classifyConfidence([r(50, 'reporter'), r(52, 'reporter')], 51)).toBe('medium');
  });
  test('low: a single community report', () => {
    expect(classifyConfidence([r(50, 'community')], 50)).toBe('low');
  });
});

describe('trendOf (±3% is flat)', () => {
  test.each([
    [103, 100, 'flat'],
    [97, 100, 'flat'],
    [103.5, 100, 'up'],
    [96, 100, 'down'],
    [50, null, 'flat'],
  ])('%p vs %p -> %p', (cur, prev, expected) => {
    expect(trendOf(cur as number, prev as number | null)).toBe(expected);
  });
});

describe('computeBoard', () => {
  test('uses only the last 24 hours for the median, previous 24h for trend', () => {
    const today = [r(60), r(62), r(58)];
    const yesterday = [
      r(50, 'reporter', { timestamp: NOW - 30 * H }),
      r(50, 'reporter', { timestamp: NOW - 40 * H }),
    ];
    const tooOld = r(10, 'reporter', { timestamp: NOW - 60 * H });
    const b = computeBoard([...today, ...yesterday, tooOld], NOW)!;
    expect(b.medianPrice).toBe(60);
    expect(b.previousMedian).toBe(50);
    expect(b.trend).toBe('up');
    expect(b.reportCount).toBe(3);
    expect(b.confidence).toBe('high');
    expect(b.sources).toEqual({ official: 0, reporter: 3, community: 0 });
  });

  test('returns null with no reports in 24h (caller keeps the stale entry)', () => {
    expect(computeBoard([r(50, 'reporter', { timestamp: NOW - 25 * H })], NOW)).toBeNull();
    expect(computeBoard([], NOW)).toBeNull();
  });

  test('ignores reports from the future', () => {
    expect(computeBoard([r(50, 'reporter', { timestamp: NOW + H })], NOW)).toBeNull();
  });

  test('emits only real status changes', () => {
    const out = r(200, 'community');
    const wasOutlier = r(51, 'community', { status: 'outlier' });
    const b = computeBoard([r(50), r(52), out, wasOutlier], NOW)!;
    expect(b.statusUpdates).toEqual(
      expect.arrayContaining([
        { id: out.id, status: 'outlier' },
        { id: wasOutlier.id, status: 'valid' },
      ]),
    );
    expect(b.statusUpdates).toHaveLength(2);
  });

  test('latestReportAt is the newest counted report; demo flag propagates', () => {
    const newest = r(50, 'community', { timestamp: NOW - 5 * 60 * 1000, isDemo: true });
    const b = computeBoard([r(50, 'community', { timestamp: NOW - 3 * H }), newest], NOW)!;
    expect(b.latestReportAt).toBe(newest.timestamp);
    expect(b.isDemo).toBe(true);
    expect(b.confidence).toBe('low');
  });
});

describe('reporterScore', () => {
  test('near median is within 15%', () => {
    expect(isNearMedian(57.5, 50)).toBe(true);
    expect(isNearMedian(58, 50)).toBe(false);
  });
  test('hit rate', () => {
    expect(nextReporterScore(0, 0, true)).toEqual({ scored: 1, near: 1, score: 1 });
    expect(nextReporterScore(3, 2, false)).toEqual({ scored: 4, near: 2, score: 0.5 });
  });
});
