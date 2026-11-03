const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
// Runs against the Auth + Firestore + Functions emulators (see `npm run test:integration`).
const { initializeApp: initAdmin } = require('firebase-admin/app');
const { getAuth: adminAuth } = require('firebase-admin/auth');
const { getFirestore: adminDb } = require('firebase-admin/firestore');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithCustomToken, signOut } = require('firebase/auth');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');

const PROJECT = 'demo-timbang';
if (!require('firebase-admin/app').getApps().length) initAdmin({ projectId: PROJECT });
const aAuth = adminAuth();
const aDb = adminDb();

let app, auth, fns;
before(() => {
  app = initializeApp({ projectId: PROJECT, apiKey: 'demo-key' });
  auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  fns = getFunctions(app, 'asia-southeast1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
});
after(() => deleteApp(app));

async function signInAs(uid, claims) {
  await aAuth.createUser({ uid }).catch(() => {});
  if (claims) await aAuth.setCustomUserClaims(uid, claims);
  const token = await aAuth.createCustomToken(uid);
  await signInWithCustomToken(auth, token);
  await auth.currentUser.getIdToken(true);
}

test('admin promotes a farmer to reporter; claim, mirror and audit are written', async () => {
  await aAuth.createUser({ uid: 'farmerX', phoneNumber: '+639171112222' }).catch(() => {});
  await aDb.doc('users/farmerX').set({ name: 'Maria', role: 'farmer', verified: false, status: 'active' });

  await signInAs('adminX', { role: 'admin' });
  const res = await httpsCallable(fns, 'setUserRole')({ uid: 'farmerX', role: 'reporter' });
  assert.deepEqual(res.data, { uid: 'farmerX', role: 'reporter' });

  assert.deepEqual((await aAuth.getUser('farmerX')).customClaims, { role: 'reporter' });
  const profile = (await aDb.doc('users/farmerX').get()).data();
  assert.equal(profile.role, 'reporter');
  assert.equal(profile.verified, true);
  const logs = await aDb.collection('audit_logs').where('targetPath', '==', 'users/farmerX').get();
  assert.ok(logs.size >= 1);
  await signOut(auth);
});

test('a non-admin cannot grant themselves admin', async () => {
  await signInAs('sneaky', { role: 'farmer' });
  await assert.rejects(httpsCallable(fns, 'setUserRole')({ uid: 'sneaky', role: 'admin' }), {
    code: 'functions/permission-denied',
  });
  assert.deepEqual((await aAuth.getUser('sneaky')).customClaims, { role: 'farmer' });
  await signOut(auth);
});

test('a user can delete their own account', async () => {
  await signInAs('leaver');
  await aDb.doc('users/leaver').set({ name: 'Leaver', status: 'active' });
  await httpsCallable(fns, 'deleteMyAccount')({});
  assert.equal((await aDb.doc('users/leaver').get()).exists, false);
  await assert.rejects(aAuth.getUser('leaver'));
});

test('export my data returns own records; deleting the account cleans them up', async () => {
  await signInAs('dataUser');
  await aDb.doc('users/dataUser').set({ name: 'Data User', phone: '+639170001111', status: 'active', role: 'farmer', fcmTokens: ['secret-token'] });
  await aDb.doc('listings/data-L1').set({ farmerId: 'dataUser', farmerName: 'Data User', farmerPhone: '+639170001111', status: 'active', commodityId: 'x', createdAt: new Date() });
  await aDb.doc('alerts/data-A1').set({ userId: 'dataUser', commodityId: 'x', marketId: 'y', threshold: 1, direction: 'above', active: true });
  await aDb.doc('price_reports/data-R1').set({ reporterId: 'dataUser', commodityId: 'x', marketId: 'y', price: 1, status: 'valid', timestamp: new Date(), batchId: 'skip' });

  const out = (await httpsCallable(fns, 'exportMyData')({})).data;
  assert.equal(out.profile.name, 'Data User');
  assert.equal(out.profile.fcmTokens, undefined);
  assert.equal(out.listings.length, 1);
  assert.equal(out.alerts.length, 1);
  assert.equal(out.priceReports.length, 1);

  await httpsCallable(fns, 'deleteMyAccount')({});
  const l = (await aDb.doc('listings/data-L1').get()).data();
  assert.equal(l.status, 'removed');
  assert.equal(l.farmerPhone, '');
  assert.equal((await aDb.doc('alerts/data-A1').get()).exists, false);
  assert.equal((await aDb.doc('price_reports/data-R1').get()).data().reporterId, 'deleted-user');
  assert.equal((await aDb.doc('users/dataUser').get()).exists, false);
});
