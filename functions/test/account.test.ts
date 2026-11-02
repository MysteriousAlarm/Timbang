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
