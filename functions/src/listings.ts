/** Listing expiry (Step 5). Pure decision + a store interface, unit tested. */
export interface ListingStore {
  now(): number;
  /** Active listings whose expiresAt is before `beforeMs`. */
  activeExpiredIds(beforeMs: number, limit: number): Promise<string[]>;
  markExpired(ids: string[]): Promise<void>;
}

/** Marks overdue active listings as expired, in pages. Returns how many were expired. */
export async function expireListings(store: ListingStore, pageSize = 400): Promise<number> {
  let total = 0;
  for (let round = 0; round < 25; round++) {
    const ids = await store.activeExpiredIds(store.now(), pageSize);
    if (ids.length === 0) break;
    await store.markExpired(ids);
    total += ids.length;
    if (ids.length < pageSize) break;
  }
  return total;
}
