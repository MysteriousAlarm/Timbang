/** Price alerts (Step 7): pure crossing logic, unit tested. */
export interface Alert {
  id: string;
  userId: string;
  threshold: number;
  direction: 'above' | 'below';
}

/**
 * Fires when the median CROSSES the threshold between the previous and the new board value,
 * so a user is told once, not on every report while the price stays past the line.
 * With no previous median (first board entry), fires if the condition already holds.
 */
export function shouldFire(a: Alert, prev: number | null, next: number): boolean {
  if (a.direction === 'above')
    return prev === null ? next >= a.threshold : prev < a.threshold && next >= a.threshold;
  return prev === null ? next <= a.threshold : prev > a.threshold && next <= a.threshold;
}

export function alertsToFire(alerts: Alert[], prev: number | null, next: number): Alert[] {
  return alerts.filter((a) => shouldFire(a, prev, next));
}

export function alertText(
  a: Alert,
  commodity: string,
  market: string,
  median: number,
  unit: string,
): { title: string; body: string } {
  const p = (v: number) => `₱${v.toFixed(2)}`;
  const verb = a.direction === 'above' ? 'umabot o lumampas sa' : 'bumaba sa o mas mababa pa sa';
  return {
    title: `TIMBANG: Alerto sa presyo ng ${commodity}`,
    body: `${commodity} sa ${market}: ${p(median)}/${unit} na, ${verb} ${p(a.threshold)} na itinakda mo.`,
  };
}
