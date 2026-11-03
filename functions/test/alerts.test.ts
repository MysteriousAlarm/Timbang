import { Alert, alertText, alertsToFire, shouldFire } from '../src/alerts';

const above: Alert = { id: 'a', userId: 'u', threshold: 60, direction: 'above' };
const below: Alert = { id: 'b', userId: 'u', threshold: 40, direction: 'below' };

test.each([
  [above, 55, 60, true],
  [above, 55, 65, true],
  [above, 61, 65, false], // already above: no repeat
  [above, 55, 59.99, false],
  [above, null, 60, true],
  [above, null, 50, false],
  [below, 45, 40, true],
  [below, 39, 35, false],
  [below, 45, 41, false],
  [below, null, 30, true],
])('%p prev=%p next=%p -> %p', (a, prev, next, expected) => {
  expect(shouldFire(a as Alert, prev as number | null, next as number)).toBe(expected);
});

test('alertsToFire filters', () => {
  expect(alertsToFire([above, below], 55, 62).map((a) => a.id)).toEqual(['a']);
});

test('alert text has the numbers, not personal data', () => {
  const t = alertText(above, 'Kamatis', 'Bayombong Public Market', 64, 'kilo');
  expect(t.body).toContain('₱64.00/kilo');
  expect(t.body).toContain('₱60.00');
});
