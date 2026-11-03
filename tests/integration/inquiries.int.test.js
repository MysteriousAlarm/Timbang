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
  app = initializeApp({ projectId: 'demo-timbang', apiKey: 'demo-key' }, 'inq');
  auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  fns = getFunctions(app, 'asia-southeast1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  await aDb.doc('users/inq-farmer').set({ name: 'Juan', phone: '+639171110000', status: 'active', role: 'farmer' });
  await aDb.doc('users/inq-buyer').set({ name: 'Bea', phone: '+639172220000', status: 'active', role: 'buyer' });
  await aDb.doc('commodities/kamatis').set({ nameFil: 'Kamatis', unit: 'kg', active: true }, { merge: true });
  await aDb.doc('listings/inq-L1').set({
    farmerId: 'inq-farmer', commodityId: 'kamatis', status: 'active',
    expiresAt: new Date(Date.now() + 86400000), createdAt: new Date(),
  });
});
after(() => deleteApp(app));

async function signInAs(uid) {
  await aAuth.createUser({ uid }).catch(() => {});
  await signInWithCustomToken(auth, await aAuth.createCustomToken(uid));
}

test('buyer inquiry reaches the farmer inbox with the buyer contact', async () => {
  await signInAs('inq-buyer');
  const res = await httpsCallable(fns, 'sendInquiry')({ listingId: 'inq-L1', message: 'Available pa po?' });
  const q = (await aDb.doc(`inquiries/${res.data.id}`).get()).data();
  assert.equal(q.farmerId, 'inq-farmer');
  assert.equal(q.buyerPhone, '+639172220000');
  assert.equal(q.status, 'new');
  await assert.rejects(
    httpsCallable(fns, 'sendInquiry')({ listingId: 'inq-L1', message: 'Ulit' }),
    { code: 'functions/already-exists' },
  );
  await signOut(auth);
});

test('farmer cannot inquire on own listing', async () => {
  await signInAs('inq-farmer');
  await assert.rejects(
    httpsCallable(fns, 'sendInquiry')({ listingId: 'inq-L1', message: 'Hi' }),
    { code: 'functions/failed-precondition' },
  );
  await signOut(auth);
});
