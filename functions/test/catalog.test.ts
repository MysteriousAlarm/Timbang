import { HttpsError } from 'firebase-functions/v2/https';
import {
  CatalogDeps,
  clearDemoCatalogHandler,
  upsertCatalogHandler,
  validateCommodity,
  validateMarket,
} from '../src/catalog';

const admin = { uid: 'admin1', role: 'admin' };
const kamatis = {
  id: 'kamatis',
  nameFil: 'Kamatis',
  nameEn: 'Tomato',
  unit: 'kg',
  category: 'Lowland vegetables',
  active: true,
};
const bayombong = {
  id: 'bayombong-public-market',
  name: 'Bayombong Public Market',
  municipality: 'Bayombong',
  type: 'public_market',
  active: true,
};

function fake() {
  const calls = { upsert: [] as unknown[], audit: [] as { action: string; detail: string }[] };
  const deps: CatalogDeps = {
    upsert: async (kind, items) => void calls.upsert.push({ kind, items }),
    deleteDemo: async () => 3,
    audit: async (e) => void calls.audit.push(e),
  };
  return { deps, calls };
}

describe('validateCommodity', () => {
  test('accepts a valid commodity and trims text', () => {
    expect(validateCommodity({ ...kamatis, nameFil: '  Kamatis ' })).toEqual(kamatis);
  });
  test('active defaults to true', () => {
    const { active: _a, ...rest } = kamatis;
    void _a;
    expect(validateCommodity(rest).active).toBe(true);
  });
  test.each([
    [{ ...kamatis, id: 'Kamatis' }, 'id'],
    [{ ...kamatis, id: 'a' }, 'id'],
    [{ ...kamatis, id: 'kamatis/../x' }, 'id'],
    [{ ...kamatis, unit: 'sack' }, 'unit'],
    [{ ...kamatis, nameFil: '' }, 'nameFil'],
    [{ ...kamatis, nameEn: 'x'.repeat(61) }, 'nameEn'],
    [{ ...kamatis, category: 5 }, 'category'],
    [{ ...kamatis, active: 'yes' }, 'active'],
    [{ ...kamatis, isDemo: true }, 'unexpected'],
  ])('rejects %p', (input, msg) => {
    expect(() => validateCommodity(input)).toThrow(msg);
  });
});

describe('validateMarket', () => {
  test('accepts a valid market', () => {
    expect(validateMarket(bayombong)).toEqual(bayombong);
  });
  test.each([
    [{ ...bayombong, municipality: 'Makati' }, 'municipality'],
    [{ ...bayombong, type: 'mall' }, 'type'],
    [{ ...bayombong, name: 'X' }, 'name'],
  ])('rejects %p', (input, msg) => {
    expect(() => validateMarket(input)).toThrow(msg);
  });
});

describe('upsertCatalog', () => {
  test('admin upserts and it is audited', async () => {
    const { deps, calls } = fake();
    await expect(
      upsertCatalogHandler(admin, { kind: 'commodities', items: [kamatis] }, deps),
    ).resolves.toEqual({ written: 1 });
    expect(calls.upsert).toEqual([{ kind: 'commodities', items: [kamatis] }]);
    expect(calls.audit[0]).toMatchObject({
      action: 'upsert_commodities',
      detail: '1 item(s): kamatis',
    });
  });

  test.each([undefined, { uid: 'u', role: 'farmer' }, { uid: 'u', role: 'reporter' }])(
    'rejects non-admin %p',
    async (who) => {
      const { deps, calls } = fake();
      await expect(
        upsertCatalogHandler(who, { kind: 'markets', items: [bayombong] }, deps),
      ).rejects.toBeInstanceOf(HttpsError);
      expect(calls.upsert).toHaveLength(0);
    },
  );

  test('one bad row rejects the whole import and reports every error', async () => {
    const { deps, calls } = fake();
    const p = upsertCatalogHandler(
      admin,
      { kind: 'commodities', items: [kamatis, { ...kamatis, id: 'x', unit: 'sack' }, kamatis] },
      deps,
    );
    await expect(p).rejects.toMatchObject({
      code: 'invalid-argument',
      details: {
        errors: [
          { row: 2, message: expect.stringContaining('id') },
          { row: 3, message: expect.stringContaining('duplicate') },
        ],
      },
    });
    expect(calls.upsert).toHaveLength(0);
  });

  test.each([
    { kind: 'users', items: [kamatis] },
    { kind: 'commodities', items: [] },
    { kind: 'commodities', items: 'x' },
    { kind: 'commodities', items: new Array(501).fill(kamatis) },
  ])('rejects bad payload %#', async (payload) => {
    const { deps } = fake();
    await expect(upsertCatalogHandler(admin, payload, deps)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });
});

describe('clearDemoCatalog', () => {
  test('admin clears demo items, audited', async () => {
    const { deps, calls } = fake();
    await expect(clearDemoCatalogHandler(admin, { kind: 'markets' }, deps)).resolves.toEqual({
      deleted: 3,
    });
    expect(calls.audit[0].action).toBe('clear_demo_markets');
  });
  test('non-admin rejected', async () => {
    const { deps } = fake();
    await expect(
      clearDemoCatalogHandler({ uid: 'u', role: 'buyer' }, { kind: 'markets' }, deps),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
