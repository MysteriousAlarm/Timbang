import { HttpsError } from 'firebase-functions/v2/https';
import { RoleDeps, setUserRoleHandler, parseSetUserRoleInput } from '../src/roles';

function fakeDeps(claims: Record<string, Record<string, unknown>> = { u1: { role: 'farmer' } }) {
  const calls = {
    setClaims: [] as [string, Record<string, unknown>][],
    mirror: [] as [string, string, boolean][],
    audit: [] as { actorId: string; action: string; targetPath: string; detail: string }[],
  };
  const deps: RoleDeps = {
    getClaims: async (uid) => claims[uid] ?? null,
    setClaims: async (uid, c) => {
      calls.setClaims.push([uid, c]);
    },
    mirrorRole: async (uid, role, verified) => {
      calls.mirror.push([uid, role, verified]);
      return true;
    },
    audit: async (e) => {
      calls.audit.push(e);
    },
  };
  return { deps, calls };
}

async function expectCode(p: Promise<unknown>, code: string) {
  await expect(p).rejects.toBeInstanceOf(HttpsError);
  await expect(p).rejects.toMatchObject({ code });
}

const admin = { uid: 'admin1', role: 'admin' };

describe('setUserRole', () => {
  test('admin can promote a farmer to reporter', async () => {
    const { deps, calls } = fakeDeps();
    await expect(setUserRoleHandler(admin, { uid: 'u1', role: 'reporter' }, deps)).resolves.toEqual(
      { uid: 'u1', role: 'reporter' },
    );
    expect(calls.setClaims).toEqual([['u1', { role: 'reporter' }]]);
    expect(calls.mirror).toEqual([['u1', 'reporter', true]]);
    expect(calls.audit).toHaveLength(1);
    expect(calls.audit[0]).toMatchObject({
      actorId: 'admin1',
      action: 'set_user_role',
      targetPath: 'users/u1',
      detail: 'farmer -> reporter',
    });
  });

  test('keeps other existing claims', async () => {
    const { deps, calls } = fakeDeps({ u1: { role: 'buyer', other: 1 } });
    await setUserRoleHandler(admin, { uid: 'u1', role: 'farmer' }, deps);
    expect(calls.setClaims[0][1]).toEqual({ role: 'farmer', other: 1 });
    expect(calls.mirror[0][2]).toBe(false);
  });

  test('rejects unauthenticated callers', async () => {
    const { deps, calls } = fakeDeps();
    await expectCode(
      setUserRoleHandler(undefined, { uid: 'u1', role: 'admin' }, deps),
      'unauthenticated',
    );
    expect(calls.setClaims).toHaveLength(0);
  });

  test.each(['farmer', 'buyer', 'reporter', undefined, 'ADMIN'])(
    'rejects non-admin caller with role %s',
    async (role) => {
      const { deps, calls } = fakeDeps();
      await expectCode(
        setUserRoleHandler({ uid: 'u1', role }, { uid: 'u1', role: 'admin' }, deps),
        'permission-denied',
      );
      expect(calls.setClaims).toHaveLength(0);
      expect(calls.audit).toHaveLength(0);
    },
  );

  test('admin cannot demote themselves', async () => {
    const { deps } = fakeDeps({ admin1: { role: 'admin' } });
    await expectCode(
      setUserRoleHandler(admin, { uid: 'admin1', role: 'farmer' }, deps),
      'failed-precondition',
    );
  });

  test('unknown user is not-found', async () => {
    const { deps } = fakeDeps();
    await expectCode(
      setUserRoleHandler(admin, { uid: 'nobody', role: 'buyer' }, deps),
      'not-found',
    );
  });
});

describe('parseSetUserRoleInput', () => {
  test.each([
    null,
    'x',
    [],
    {},
    { uid: 'u1' },
    { role: 'admin' },
    { uid: 'u1', role: 'superadmin' },
    { uid: '', role: 'buyer' },
    { uid: 'a/b', role: 'buyer' },
    { uid: 'x'.repeat(129), role: 'buyer' },
    { uid: 'u1', role: 'buyer', extra: true },
    { uid: 1, role: 'buyer' },
  ])('rejects %p', (input) => {
    expect(() => parseSetUserRoleInput(input)).toThrow(HttpsError);
  });
  test('accepts valid input', () => {
    expect(parseSetUserRoleInput({ uid: 'abc_DEF-1', role: 'admin' })).toEqual({
      uid: 'abc_DEF-1',
      role: 'admin',
    });
  });
});
