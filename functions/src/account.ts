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
  /** Optional cleanup of the user's other data (Step 10). Returns counts for the audit detail. */
  cleanup?(uid: string): Promise<Record<string, number>>;
}

/**
 * RA 10173 right to erasure: deletes the profile, auth user and the user's own content.
 * Listings are removed (and their photos deleted), alerts and inquiries deleted; price reports
 * are kept for price integrity but unlinked from the person (reporterId anonymized).
 */
export async function deleteMyAccountHandler(
  caller: { uid: string } | undefined,
  deps: AccountDeps,
): Promise<{ deleted: true }> {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  const counts = deps.cleanup ? await deps.cleanup(caller.uid) : {};
  await deps.deleteProfile(caller.uid);
  await deps.deleteAuthUser(caller.uid);
  // No personal data in the audit log: only the uid path and counts.
  const detail = Object.keys(counts).length
    ? `self; ${Object.entries(counts)
        .map(([k, v]) => `${k}=${v}`)
        .join(', ')}`
    : 'self';
  await deps.audit({
    actorId: caller.uid,
    action: 'delete_account',
    targetPath: `users/${caller.uid}`,
    detail,
  });
  return { deleted: true };
}

export interface ExportDeps {
  collect(uid: string): Promise<Record<string, unknown>>;
  audit(entry: {
    actorId: string;
    action: string;
    targetPath: string;
    detail: string;
  }): Promise<void>;
}

/** RA 10173 right of access: everything TIMBANG holds about the caller, as JSON. */
export async function exportMyDataHandler(caller: { uid: string } | undefined, deps: ExportDeps) {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  const data = await deps.collect(caller.uid);
  await deps.audit({
    actorId: caller.uid,
    action: 'export_my_data',
    targetPath: `users/${caller.uid}`,
    detail: 'self',
  });
  return { exportedAt: new Date().toISOString(), ...data };
}
