const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
// Runs against the Auth + Firestore + Functions emulators (see `npm run test:integration`).
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

before(() => {
  app = initializeApp({ projectId: 'demo-timbang', apiKey: 'demo-key' }, 'catalog');
  auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  fns = getFunctions(app, 'asia-southeast1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
});
after(() => deleteApp(app));

async function signInAs(uid, claims) {
  await aAuth.createUser({ uid }).catch(() => {});
  await aAuth.setCustomUserClaims(uid, claims);
  await signInWithCustomToken(auth, await aAuth.createCustomToken(uid));
  await auth.currentUser.getIdToken(true);
}

test('admin imports commodities; demo data is cleared separately', async () => {
  await aDb.doc('commodities/okra').set({ nameFil: 'Okra', isDemo: true });
  await signInAs('catAdmin', { role: 'admin' });
  const res = await httpsCallable(fns, 'upsertCatalog')({
    kind: 'commodities',
    items: [{ id: 'kamatis', nameFil: 'Kamatis', nameEn: 'Tomato', unit: 'kg', category: 'Lowland vegetables' }],
  });
  assert.deepEqual(res.data, { written: 1 });
  const k = (await aDb.doc('commodities/kamatis').get()).data();
  assert.equal(k.isDemo, false);
  assert.equal(k.active, true);

  const cleared = await httpsCallable(fns, 'clearDemoCatalog')({ kind: 'commodities' });
  assert.equal(cleared.data.deleted, 1);
  assert.equal((await aDb.doc('commodities/okra').get()).exists, false);
  assert.equal((await aDb.doc('commodities/kamatis').get()).exists, true);
  await signOut(auth);
});

test('invalid rows return per-row errors and write nothing', async () => {
  await signInAs('catAdmin2', { role: 'admin' });
  await assert.rejects(
    httpsCallable(fns, 'upsertCatalog')({
      kind: 'markets',
      items: [{ id: 'm1', name: 'Mall', municipality: 'Makati', type: 'mall' }],
    }),
    (e) => e.code === 'functions/invalid-argument' && e.details.errors[0].row === 1,
  );
  assert.equal((await aDb.doc('markets/m1').get()).exists, false);
  await signOut(auth);
});

test('farmer cannot write the catalog', async () => {
  await signInAs('catFarmer', { role: 'farmer' });
  await assert.rejects(
    httpsCallable(fns, 'upsertCatalog')({
      kind: 'markets',
      items: [{ id: 'x1', name: 'Fake Market', municipality: 'Solano', type: 'public_market' }],
    }),
    { code: 'functions/permission-denied' },
  );
  await signOut(auth);
});
