import { onCall } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2';
import { FieldValue } from 'firebase-admin/firestore';
import { REGION } from './config';
import { auth, db, writeAudit } from './firebase';
import { setUserRoleHandler, RoleDeps } from './roles';
import { deleteMyAccountHandler } from './account';

setGlobalOptions({ region: REGION, maxInstances: 5 });

const roleDeps: RoleDeps = {
  async getClaims(uid) {
    try {
      const user = await auth.getUser(uid);
      return user.customClaims ?? {};
    } catch {
      return null;
    }
  },
  async setClaims(uid, claims) {
    await auth.setCustomUserClaims(uid, claims);
  },
  async mirrorRole(uid, role, verified) {
    const ref = db.collection('users').doc(uid);
    const snap = await ref.get();
    if (!snap.exists) return false;
    await ref.update({ role, verified, updatedAt: FieldValue.serverTimestamp() });
    return true;
  },
  audit: writeAudit,
};

/** Admin-only callable: set a user's role custom claim. */
export const setUserRole = onCall((req) =>
  setUserRoleHandler(
    req.auth ? { uid: req.auth.uid, role: req.auth.token.role } : undefined,
    req.data,
    roleDeps,
  ),
);

/** Callable: the signed-in user deletes their own account (RA 10173). */
export const deleteMyAccount = onCall((req) =>
  deleteMyAccountHandler(req.auth ? { uid: req.auth.uid } : undefined, {
    deleteProfile: async (uid) => {
      await db.collection('users').doc(uid).delete();
    },
    deleteAuthUser: (uid) => auth.deleteUser(uid),
    audit: writeAudit,
  }),
);
