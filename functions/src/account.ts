import { HttpsError } from 'firebase-functions/v2/https';

export interface AccountDeps {
  deleteProfile(uid: string): Promise<void>;
  deleteAuthUser(uid: string): Promise<void>;
  audit(entry: {
    actorId: string;
    action: string;
    targetPath: string;
    detail: string;
  }): Promise<void>;
}

/**
 * RA 10173 right to erasure: a signed-in user deletes their own account and profile.
 * Listings/inquiries cleanup is added in Steps 5-6.
 */
export async function deleteMyAccountHandler(
  caller: { uid: string } | undefined,
  deps: AccountDeps,
): Promise<{ deleted: true }> {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  await deps.deleteProfile(caller.uid);
  await deps.deleteAuthUser(caller.uid);
  // No personal data in the audit log: only the uid path.
  await deps.audit({
    actorId: caller.uid,
    action: 'delete_account',
    targetPath: `users/${caller.uid}`,
    detail: 'self',
  });
  return { deleted: true };
}
