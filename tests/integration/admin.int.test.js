const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { initializeApp: initAdmin, getApps } = require('firebase-admin/app');
const { getAuth: adminAuth } = require('firebase-admin/auth');
const { getFirestore: adminDb } = require('firebase-admin/firestore');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithCustomToken, signOut } = require('firebase/auth');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');

if (!getApps().length) initAdmin({ projectId: 'demo-timbang' });
const aAuth = adminAuth();
const aDb = adminDb();
let app, auth, fns;

before(async () => {
  app = initializeApp({ projectId: 'demo-timbang', apiKey: 'demo-key' }, 'adm');
  auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  fns = getFunctions(app, 'asia-southeast1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  await aDb.doc('commodities/ampalaya2').set({ nameFil: 'Ampalaya', unit: 'kg', active: true });
  await aDb.doc('markets/adm-market').set({ name: 'Adm Market', municipality: 'Solano', type: 'public_market', active: true });
  await aAuth.createUser({ uid: 'adm-admin' }).catch(() => {});
  await aAuth.setCustomUserClaims('adm-admin', { role: 'admin' });
  await aDb.doc('users/adm-admin').set({ name: 'Admin', status: 'active', role: 'admin' });
  await signInWithCustomToken(auth, await aAuth.createCustomToken('adm-admin'));
  await auth.currentUser.getIdToken(true);
});
after(async () => {
  await signOut(auth);
  await deleteApp(app);
});

test('rejecting the only report removes the bogus price from the board', async () => {
  const ref = await aDb.collection('price_reports').add({
    commodityId: 'ampalaya2', marketId: 'adm-market', price: 999, unit: 'kg', reporterId: 'x',
    reporterRole: 'member', source: 'community', status: 'valid', isDemo: false, timestamp: new Date(),
  });
  const boardRef = aDb.doc('price_board/ampalaya2_adm-market');
  for (let i = 0; i < 50 && !(await boardRef.get()).exists; i++) await new Promise((r) => setTimeout(r, 200));
  assert.equal((await boardRef.get()).data().medianPrice, 999);
  await httpsCallable(fns, 'moderateReport')({ reportId: ref.id, action: 'reject', reason: 'Malayong presyo' });
  assert.equal((await ref.get()).data().status, 'rejected');
  assert.equal((await boardRef.get()).exists, false);
  const logs = await aDb.collection('audit_logs').where('targetPath', '==', `price_reports/${ref.id}`).get();
  assert.equal(logs.size, 1);
});

test('pilot metrics are computed for admins', async () => {
  const m = (await httpsCallable(fns, 'getPilotMetrics')({})).data;
  assert.equal(typeof m.listings30d, 'number');
  assert.ok('usersByRole' in m);
});
