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

before(async () => {
  app = initializeApp({ projectId: 'demo-timbang', apiKey: 'demo-key' }, 'prices');
  auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  fns = getFunctions(app, 'asia-southeast1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  await aDb.doc('commodities/talong').set({ nameFil: 'Talong', nameEn: 'Eggplant', unit: 'kg', category: 'x', active: true });
  await aDb.doc('markets/test-market').set({ name: 'Test Market', municipality: 'Solano', type: 'public_market', active: true });
});
after(() => deleteApp(app));

async function signInAs(uid, claims) {
  await aAuth.createUser({ uid }).catch(() => {});
  if (claims) await aAuth.setCustomUserClaims(uid, claims);
  await aDb.doc(`users/${uid}`).set({ name: uid, status: 'active' }, { merge: true });
  await signInWithCustomToken(auth, await aAuth.createCustomToken(uid));
  await auth.currentUser.getIdToken(true);
}

async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error('timed out');
}

const board = () => aDb.doc('price_board/talong_test-market').get();

test('reports flow into the price board via the trigger', async () => {
  await signInAs('pr-rep', { role: 'reporter' });
  const res = await httpsCallable(fns, 'submitPriceReport')({ commodityId: 'talong', marketId: 'test-market', price: 60 });
  assert.equal(res.data.source, 'reporter');
  await signOut(auth);

  let b = await waitFor(async () => {
    const s = await board();
    return s.exists && s.data().reportCount === 1 ? s.data() : null;
  });
  assert.equal(b.medianPrice, 60);
  assert.equal(b.confidence, 'medium');
  assert.equal(b.unit, 'kg');

  for (const [uid, price] of [['pr-f1', 62], ['pr-f2', 58]]) {
    await signInAs(uid);
    const r = await httpsCallable(fns, 'submitPriceReport')({ commodityId: 'talong', marketId: 'test-market', price });
    assert.equal(r.data.source, 'community');
    await signOut(auth);
  }
  b = await waitFor(async () => {
    const s = await board();
    return s.data().reportCount === 3 ? s.data() : null;
  });
  assert.equal(b.medianPrice, 60);
  assert.equal(b.confidence, 'high');
  assert.deepEqual(b.sources, { official: 0, reporter: 1, community: 2 });

  const score = (await aDb.doc('users/pr-rep').get()).data();
  assert.equal(score.reporterScore, 1);
});

test('admin official import makes the price high confidence', async () => {
  await aDb.doc('commodities/okra2').set({ nameFil: 'Okra', nameEn: 'Okra', unit: 'kg', category: 'x', active: true });
  await signInAs('pr-admin', { role: 'admin' });
  const res = await httpsCallable(fns, 'importOfficialPrices')({
    sourceNote: 'DA Bantay Presyo',
    rows: [{ commodityId: 'okra2', marketId: 'test-market', price: 80 }],
  });
  assert.deepEqual(res.data, { written: 1, boards: 1 });
  const b = (await aDb.doc('price_board/okra2_test-market').get()).data();
  assert.equal(b.confidence, 'high');
  assert.equal(b.sources.official, 1);
  await signOut(auth);
});

test('a farmer cannot import official prices', async () => {
  await signInAs('pr-f3', { role: 'farmer' });
  await assert.rejects(
    httpsCallable(fns, 'importOfficialPrices')({ sourceNote: 'Fake', rows: [{ commodityId: 'talong', marketId: 'test-market', price: 1 }] }),
    { code: 'functions/permission-denied' },
  );
  await signOut(auth);
});

test('a price crossing an alert threshold marks the alert as triggered', async () => {
  await aDb.doc('commodities/sitaw2').set({ nameFil: 'Sitaw', nameEn: 'String beans', unit: 'bundle', category: 'x', active: true });
  await aDb.doc('alerts/al-1').set({
    userId: 'pr-f1', commodityId: 'sitaw2', marketId: 'test-market', threshold: 30,
    direction: 'above', active: true, createdAt: new Date(),
  });
  await signInAs('pr-admin2', { role: 'admin' });
  await httpsCallable(fns, 'importOfficialPrices')({
    sourceNote: 'DA test', rows: [{ commodityId: 'sitaw2', marketId: 'test-market', price: 32 }],
  });
  const a = await waitFor(async () => {
    const d = (await aDb.doc('alerts/al-1').get()).data();
    return d.lastTriggeredMedian ? d : null;
  });
  assert.equal(a.lastTriggeredMedian, 32);
  await signOut(auth);
});
