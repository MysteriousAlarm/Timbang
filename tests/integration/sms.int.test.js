const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('crypto');
const { initializeApp: initAdmin, getApps } = require('firebase-admin/app');
const { getAuth: adminAuth } = require('firebase-admin/auth');
const { getFirestore: adminDb } = require('firebase-admin/firestore');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithCustomToken, signOut } = require('firebase/auth');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');

if (!getApps().length) initAdmin({ projectId: 'demo-timbang' });
const aAuth = adminAuth();
const aDb = adminDb();
const URL = 'http://127.0.0.1:5001/demo-timbang/asia-southeast1/smsWebhook';
const SECRET = 'dev-only-sms-secret';
let app, auth, fns;

before(async () => {
  app = initializeApp({ projectId: 'demo-timbang', apiKey: 'demo-key' }, 'sms');
  auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  fns = getFunctions(app, 'asia-southeast1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  await aDb.doc('commodities/okra-sms').set({ nameFil: 'Okrasms', nameEn: 'Okra test', unit: 'kg', active: true });
  await aDb.doc('markets/sms-market').set({ name: 'SMS Test Market', municipality: 'Kayapa', type: 'public_market', active: true });
  await aDb.doc('price_board/okra-sms_sms-market').set({
    commodityId: 'okra-sms', marketId: 'sms-market', unit: 'kg', medianPrice: 42.5, confidence: 'medium',
    reportCount: 2, trend: 'flat', isDemo: false, latestReportAt: new Date(Date.now() - 3600_000),
  });
});
after(() => deleteApp(app));

const post = (body, sig) =>
  fetch(URL, { method: 'POST', headers: { 'content-type': 'application/json', ...(sig ? { 'x-timbang-signature': sig } : {}) }, body });

test('webhook rejects unsigned and wrongly signed requests', async () => {
  const body = JSON.stringify({ from: '+639171234567', text: 'PRESYO OKRASMS' });
  assert.equal((await post(body)).status, 401);
  assert.equal((await post(body, createHmac('sha256', 'wrong').update(body).digest('hex'))).status, 401);
  assert.equal((await fetch(URL)).status, 405);
});

test('signed webhook is accepted and rate-limited by hashed number', async () => {
  const body = JSON.stringify({ from: '+639179990000', text: 'PRESYO OKRASMS KAYAPA' });
  const sig = createHmac('sha256', SECRET).update(body).digest('hex');
  assert.equal((await post(body, sig)).status, 200);
  const rate = await aDb.collection('sms_rate').get();
  assert.ok(rate.size >= 1);
  assert.ok(rate.docs.every((d) => !d.id.includes('9179990000')));
});

test('admin simulator returns the real reply', async () => {
  await aAuth.createUser({ uid: 'sms-admin' }).catch(() => {});
  await aAuth.setCustomUserClaims('sms-admin', { role: 'admin' });
  await signInWithCustomToken(auth, await aAuth.createCustomToken('sms-admin'));
  await auth.currentUser.getIdToken(true);
  const r = await httpsCallable(fns, 'simulateSms')({ text: 'presyo okrasms kayapa' });
  assert.match(r.data.reply, /SMS Test Market P42\.50\/kilo, Katamtaman, 1 oras na/);
  await signOut(auth);
});
