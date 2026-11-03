import { HttpsError } from 'firebase-functions/v2/https';
import { ROLES, Role } from './config';

/** Minimal view of the caller, taken from the verified ID token. */
export interface Caller {
  uid: string;
  role?: unknown;
}

/** Side effects, injected so the logic can be unit tested without the emulator. */
export interface RoleDeps {
  getClaims(uid: string): Promise<Record<string, unknown> | null>;
  setClaims(uid: string, claims: Record<string, unknown>): Promise<void>;
  /** Mirror the role into users/{uid} for display only. Returns false if no profile exists. */
  mirrorRole(uid: string, role: Role, verified: boolean): Promise<boolean>;
  audit(entry: {
    actorId: string;
    action: string;
    targetPath: string;
    detail: string;
  }): Promise<void>;
}

export interface SetUserRoleInput {
  uid: string;
  role: Role;
}

const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export function parseSetUserRoleInput(data: unknown): SetUserRoleInput {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'Expected an object { uid, role }.');
  }
  const { uid, role, ...rest } = data as Record<string, unknown>;
  if (Object.keys(rest).length > 0) {
    throw new HttpsError('invalid-argument', 'Unexpected fields.');
  }
  if (typeof uid !== 'string' || !UID_PATTERN.test(uid)) {
    throw new HttpsError('invalid-argument', 'Invalid uid.');
  }
  if (typeof role !== 'string' || !(ROLES as readonly string[]).includes(role)) {
    throw new HttpsError('invalid-argument', `role must be one of: ${ROLES.join(', ')}.`);
  }
  return { uid, role: role as Role };
}

/**
 * Admin-only: set a user's role custom claim.
 * Clients can never set their own role; this is the only path that writes the claim.
 */
export async function setUserRoleHandler(
  caller: Caller | undefined,
  data: unknown,
  deps: RoleDeps,
): Promise<{ uid: string; role: Role }> {
  if (!caller) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (caller.role !== 'admin') throw new HttpsError('permission-denied', 'Admins only.');

  const { uid, role } = parseSetUserRoleInput(data);
  if (uid === caller.uid && role !== 'admin') {
    // Prevents an admin from locking the province out by accident.
    throw new HttpsError('failed-precondition', 'Admins cannot remove their own admin role.');
  }

  const existing = await deps.getClaims(uid);
  if (existing === null) throw new HttpsError('not-found', 'User not found.');

  const previous = typeof existing.role === 'string' ? existing.role : 'none';
  await deps.setClaims(uid, { ...existing, role });
  // reporter/admin are vetted by an admin, so they are marked verified.
  await deps.mirrorRole(uid, role, role === 'reporter' || role === 'admin');
  await deps.audit({
    actorId: caller.uid,
    action: 'set_user_role',
    targetPath: `users/${uid}`,
    detail: `${previous} -> ${role}`,
  });
  return { uid, role };
}
