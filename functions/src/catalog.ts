import { HttpsError } from 'firebase-functions/v2/https';
import {
  CATALOG_ID_PATTERN,
  CATALOG_MAX_ITEMS_PER_CALL,
  MARKET_TYPES,
  MUNICIPALITIES,
  UNITS,
} from './config';

export type CatalogKind = 'commodities' | 'markets';

export interface Commodity {
  id: string;
  nameFil: string;
  nameEn: string;
  unit: (typeof UNITS)[number];
  category: string;
  active: boolean;
}

export interface Market {
  id: string;
  name: string;
  municipality: (typeof MUNICIPALITIES)[number];
  type: (typeof MARKET_TYPES)[number];
  active: boolean;
}

type Item = Commodity | Market;

function str(v: unknown, field: string, min: number, max: number): string {
  if (typeof v !== 'string') throw new Error(`${field}: required text`);
  const t = v.trim();
  if (t.length < min || t.length > max) throw new Error(`${field}: ${min}-${max} characters`);
  return t;
}

function oneOf<T extends string>(v: unknown, field: string, allowed: readonly T[]): T {
  if (typeof v !== 'string' || !(allowed as readonly string[]).includes(v)) {
    throw new Error(`${field}: must be one of ${allowed.join(', ')}`);
  }
  return v as T;
}

function onlyKeys(o: Record<string, unknown>, keys: string[]) {
  const extra = Object.keys(o).filter((k) => !keys.includes(k));
  if (extra.length) throw new Error(`unexpected field(s): ${extra.join(', ')}`);
}

function id(v: unknown): string {
  if (typeof v !== 'string' || !CATALOG_ID_PATTERN.test(v)) {
    throw new Error('id: lowercase letters, numbers and dashes (2-49 chars)');
  }
  return v;
}

export function validateCommodity(raw: unknown): Commodity {
  if (typeof raw !== 'object' || raw === null) throw new Error('not an object');
  const o = raw as Record<string, unknown>;
  onlyKeys(o, ['id', 'nameFil', 'nameEn', 'unit', 'category', 'active']);
  return {
    id: id(o.id),
    nameFil: str(o.nameFil, 'nameFil', 1, 60),
    nameEn: str(o.nameEn, 'nameEn', 1, 60),
    unit: oneOf(o.unit, 'unit', UNITS),
    category: str(o.category, 'category', 1, 40),
    active: o.active === undefined ? true : bool(o.active),
  };
}

export function validateMarket(raw: unknown): Market {
  if (typeof raw !== 'object' || raw === null) throw new Error('not an object');
  const o = raw as Record<string, unknown>;
  onlyKeys(o, ['id', 'name', 'municipality', 'type', 'active']);
  return {
    id: id(o.id),
    name: str(o.name, 'name', 2, 80),
    municipality: oneOf(o.municipality, 'municipality', MUNICIPALITIES),
    type: oneOf(o.type, 'type', MARKET_TYPES),
    active: o.active === undefined ? true : bool(o.active),
  };
}

function bool(v: unknown): boolean {
  if (typeof v !== 'boolean') throw new Error('active: must be true or false');
  return v;
}

export interface CatalogDeps {
  /** Upsert items (merge) with server timestamps; imported data is never demo data. */
  upsert(kind: CatalogKind, items: Item[]): Promise<void>;
  /** Delete every document with isDemo == true. Returns the count. */
  deleteDemo(kind: CatalogKind): Promise<number>;
  audit(entry: {
    actorId: string;
    action: string;
    targetPath: string;
    detail: string;
  }): Promise<void>;
}

function requireAdmin(caller: { uid: string; role?: unknown } | undefined) {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (caller.role !== 'admin') throw new HttpsError('permission-denied', 'Admins only.');
  return caller;
}

function parseKind(v: unknown): CatalogKind {
  if (v !== 'commodities' && v !== 'markets') {
    throw new HttpsError('invalid-argument', 'kind must be commodities or markets.');
  }
  return v;
}

/**
 * Admin-only: create or update commodities/markets (single form edit or CSV import).
 * All-or-nothing: if any row is invalid nothing is written and every row error is returned.
 */
export async function upsertCatalogHandler(
  caller: { uid: string; role?: unknown } | undefined,
  data: unknown,
  deps: CatalogDeps,
): Promise<{ written: number }> {
  const admin = requireAdmin(caller);
  const d = (typeof data === 'object' && data !== null ? data : {}) as Record<string, unknown>;
  const kind = parseKind(d.kind);
  if (!Array.isArray(d.items) || d.items.length === 0) {
    throw new HttpsError('invalid-argument', 'items must be a non-empty list.');
  }
  if (d.items.length > CATALOG_MAX_ITEMS_PER_CALL) {
    throw new HttpsError(
      'invalid-argument',
      `At most ${CATALOG_MAX_ITEMS_PER_CALL} items per call.`,
    );
  }
  const validate = kind === 'commodities' ? validateCommodity : validateMarket;
  const items: Item[] = [];
  const errors: { row: number; message: string }[] = [];
  const seen = new Set<string>();
  d.items.forEach((raw, i) => {
    try {
      const item = validate(raw);
      if (seen.has(item.id)) throw new Error(`id: duplicate "${item.id}"`);
      seen.add(item.id);
      items.push(item);
    } catch (e) {
      errors.push({ row: i + 1, message: (e as Error).message });
    }
  });
  if (errors.length) {
    throw new HttpsError('invalid-argument', 'Some rows are invalid.', { errors });
  }
  await deps.upsert(kind, items);
  await deps.audit({
    actorId: admin.uid,
    action: `upsert_${kind}`,
    targetPath: kind,
    detail: `${items.length} item(s): ${items
      .slice(0, 10)
      .map((x) => x.id)
      .join(', ')}${items.length > 10 ? ', ...' : ''}`,
  });
  return { written: items.length };
}

/** Admin-only: remove seeded demo items once the official lists arrive. */
export async function clearDemoCatalogHandler(
  caller: { uid: string; role?: unknown } | undefined,
  data: unknown,
  deps: CatalogDeps,
): Promise<{ deleted: number }> {
  const admin = requireAdmin(caller);
  const kind = parseKind((data as Record<string, unknown> | null)?.kind);
  const deleted = await deps.deleteDemo(kind);
  await deps.audit({
    actorId: admin.uid,
    action: `clear_demo_${kind}`,
    targetPath: kind,
    detail: `${deleted} demo item(s) deleted`,
  });
  return { deleted };
}
