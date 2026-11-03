import { deleteMyAccountHandler } from '../src/account';

describe('deleteMyAccount', () => {
  test('deletes own profile and auth user, then audits without PII', async () => {
    const log: string[] = [];
    const audits: unknown[] = [];
    await deleteMyAccountHandler(
      { uid: 'u1' },
      {
        deleteProfile: async (uid) => void log.push(`profile:${uid}`),
        deleteAuthUser: async (uid) => void log.push(`auth:${uid}`),
        audit: async (e) => void audits.push(e),
      },
    );
    expect(log).toEqual(['profile:u1', 'auth:u1']);
    expect(audits).toEqual([
      { actorId: 'u1', action: 'delete_account', targetPath: 'users/u1', detail: 'self' },
    ]);
  });

  test('rejects unauthenticated', async () => {
    await expect(
      deleteMyAccountHandler(undefined, {
        deleteProfile: jest.fn(),
        deleteAuthUser: jest.fn(),
        audit: jest.fn(),
      }),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });
});

describe('Step 10 data rights', () => {
  test('cleanup runs before deletion and counts go in the audit, not PII', async () => {
    const order: string[] = [];
    const audits: { detail: string }[] = [];
    await deleteMyAccountHandler(
      { uid: 'u1' },
      {
        cleanup: async () => {
          order.push('cleanup');
          return { listings: 2, alerts: 1 };
        },
        deleteProfile: async () => void order.push('profile'),
        deleteAuthUser: async () => void order.push('auth'),
        audit: async (e) => void audits.push(e),
      },
    );
    expect(order).toEqual(['cleanup', 'profile', 'auth']);
    expect(audits[0].detail).toBe('self; listings=2, alerts=1');
  });

  test('export returns the collected data and is audited', async () => {
    const { exportMyDataHandler } = await import('../src/account');
    const audits: string[] = [];
    const out = await exportMyDataHandler(
      { uid: 'u1' },
      {
        collect: async () => ({ profile: { name: 'Juan' } }),
        audit: async (e) => void audits.push(e.action),
      },
    );
    expect(out).toMatchObject({ profile: { name: 'Juan' } });
    expect(audits).toEqual(['export_my_data']);
    await expect(
      exportMyDataHandler(undefined, { collect: jest.fn(), audit: jest.fn() }),
    ).rejects.toMatchObject({ code: 'unauthenticated' });
  });
});
