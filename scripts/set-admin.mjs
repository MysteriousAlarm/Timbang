#!/usr/bin/env node
// Local-only bootstrap: grant the FIRST admin role claim. Never deployed.
//
// Emulator:   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//               npm run seed:admin -- +639171234567
// Real project (once): GOOGLE_APPLICATION_CREDENTIALS=/path/outside/repo/sa.json \
//               GCLOUD_PROJECT=<project-id> npm run seed:admin -- +639171234567
// After that, every other role change goes through the admin-only `setUserRole` function.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const phone = process.argv[2];
if (!phone || !/^\+639\d{9}$/.test(phone)) {
  console.error('Usage: npm run seed:admin -- +639XXXXXXXXX');
  process.exit(1);
}
const projectId = process.env.GCLOUD_PROJECT || 'demo-timbang';
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST && projectId === 'demo-timbang') {
  console.error('Set FIREBASE_AUTH_EMULATOR_HOST for the emulator, or GCLOUD_PROJECT for a real project.');
  process.exit(1);
}

initializeApp({ projectId });
const auth = getAuth();
const db = getFirestore();

const user = await auth.getUserByPhoneNumber(phone).catch(() => null);
if (!user) {
  console.error('No user with that phone. Sign in once in the app first.');
  process.exit(1);
}
await auth.setCustomUserClaims(user.uid, { ...(user.customClaims ?? {}), role: 'admin' });
const ref = db.collection('users').doc(user.uid);
if ((await ref.get()).exists) {
  await ref.update({ role: 'admin', verified: true, updatedAt: FieldValue.serverTimestamp() });
}
await db.collection('audit_logs').add({
  actorId: 'bootstrap-script',
  action: 'set_user_role',
  targetPath: `users/${user.uid}`,
  detail: 'bootstrap -> admin',
  timestamp: FieldValue.serverTimestamp(),
});
console.log(`Granted admin to ${user.uid}. They must sign out and in again (or refresh their token).`);
process.exit(0);
