const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, collection, addDoc,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-timbang';
let env;

const FARMER_UID = 'farmer1';
const FARMER_PHONE = '+639171234567';

const farmerCtx = () =>
  env.authenticatedContext(FARMER_UID, { phone_number: FARMER_PHONE }).firestore();
const otherCtx = () =>
  env.authenticatedContext('other1', { phone_number: '+639170000000' }).firestore();
const adminCtx = () =>
  env.authenticatedContext('admin1', { role: 'admin', phone_number: '+639179999999' }).firestore();
const anonCtx = () => env.unauthenticatedContext().firestore();

function newProfile(overrides = {}) {
  return {
    name: 'Juan Dela Cruz',
    phone: FARMER_PHONE,
    municipality: 'Bayombong',
    role: 'farmer',
    verified: false,
    status: 'active',
    createdAt: serverTimestamp(),
    consentAt: serverTimestamp(),
    ...overrides,
  };
}

async function seedProfile(data = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', FARMER_UID), {
      name: 'Juan Dela Cruz',
      phone: FARMER_PHONE,
      municipality: 'Bayombong',
      role: 'farmer',
      verified: false,
      status: 'active',
      createdAt: new Date(),
      consentAt: new Date(),
      ...data,
    });
  });
}

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
afterAll(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

describe('users: create', () => {
  test('farmer can create own profile', async () => {
    await assertSucceeds(setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile()));
  });
  test('buyer can create own profile', async () => {
    await assertSucceeds(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ role: 'buyer' })),
    );
  });
  test.each(['admin', 'reporter', 'superuser'])('client cannot self-assign role %s', async (role) => {
    await assertFails(setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ role })));
  });
  test('cannot create profile for another uid', async () => {
    await assertFails(setDoc(doc(otherCtx(), 'users', FARMER_UID), newProfile()));
  });
  test('unauthenticated cannot create', async () => {
    await assertFails(setDoc(doc(anonCtx(), 'users', FARMER_UID), newProfile()));
  });
  test('phone must match the verified auth phone', async () => {
    await assertFails(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ phone: '+639998887777' })),
    );
  });
  test('cannot self-verify', async () => {
    await assertFails(setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ verified: true })));
  });
  test('cannot set status other than active', async () => {
    await assertFails(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ status: 'suspended' })),
    );
  });
  test('rejects extra PII fields (data minimization)', async () => {
    await assertFails(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ birthday: '1990-01-01' })),
    );
    await assertFails(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ reporterScore: 1 })),
    );
  });
  test('rejects municipality outside Nueva Vizcaya', async () => {
    await assertFails(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ municipality: 'Makati' })),
    );
  });
  test('rejects too short / too long names', async () => {
    await assertFails(setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ name: 'J' })));
    await assertFails(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ name: 'x'.repeat(81) })),
    );
  });
  test('requires consent timestamp', async () => {
    const p = newProfile();
    delete p.consentAt;
    await assertFails(setDoc(doc(farmerCtx(), 'users', FARMER_UID), p));
  });
  test('client-supplied createdAt is rejected', async () => {
    await assertFails(
      setDoc(doc(farmerCtx(), 'users', FARMER_UID), newProfile({ createdAt: new Date(0) })),
    );
  });
});

describe('users: read', () => {
  beforeEach(() => seedProfile());
  test('owner can read', async () => {
    await assertSucceeds(getDoc(doc(farmerCtx(), 'users', FARMER_UID)));
  });
  test('admin can read', async () => {
    await assertSucceeds(getDoc(doc(adminCtx(), 'users', FARMER_UID)));
  });
  test('other user cannot read', async () => {
    await assertFails(getDoc(doc(otherCtx(), 'users', FARMER_UID)));
  });
  test('unauthenticated cannot read', async () => {
    await assertFails(getDoc(doc(anonCtx(), 'users', FARMER_UID)));
  });
});

describe('users: update', () => {
  beforeEach(() => seedProfile());
  test('owner can update name and municipality', async () => {
    await assertSucceeds(
      updateDoc(doc(farmerCtx(), 'users', FARMER_UID), {
        name: 'Juan D. Cruz',
        municipality: 'Solano',
        updatedAt: serverTimestamp(),
      }),
    );
  });
  test('owner can update fcmTokens', async () => {
    await assertSucceeds(updateDoc(doc(farmerCtx(), 'users', FARMER_UID), { fcmTokens: ['t1'] }));
  });
  test.each([
    ['role', 'admin'],
    ['role', 'reporter'],
    ['verified', true],
    ['status', 'active2'],
    ['reporterScore', 1],
    ['assignedMarketIds', ['m1']],
    ['phone', '+639170000001'],
  ])('owner cannot change %s', async (field, value) => {
    await assertFails(updateDoc(doc(farmerCtx(), 'users', FARMER_UID), { [field]: value }));
  });
  test('suspended user cannot update', async () => {
    await seedProfile({ status: 'suspended' });
    await assertFails(updateDoc(doc(farmerCtx(), 'users', FARMER_UID), { name: 'Bagong Pangalan' }));
  });
  test('other user cannot update', async () => {
    await assertFails(updateDoc(doc(otherCtx(), 'users', FARMER_UID), { name: 'Hacker' }));
  });
  test('admin client cannot write users directly (functions only)', async () => {
    await assertFails(updateDoc(doc(adminCtx(), 'users', FARMER_UID), { role: 'reporter' }));
  });
  test('owner cannot delete directly', async () => {
    await assertFails(deleteDoc(doc(farmerCtx(), 'users', FARMER_UID)));
  });
});

describe('price_board (functions only)', () => {
  test('signed-in user can read', async () => {
    await assertSucceeds(getDoc(doc(farmerCtx(), 'price_board', 'kamatis_bayombong')));
  });
  test('unauthenticated cannot read', async () => {
    await assertFails(getDoc(doc(anonCtx(), 'price_board', 'kamatis_bayombong')));
  });
  test('nobody can write from a client, not even admin', async () => {
    await assertFails(setDoc(doc(farmerCtx(), 'price_board', 'x'), { medianPrice: 1 }));
    await assertFails(setDoc(doc(adminCtx(), 'price_board', 'x'), { medianPrice: 1 }));
  });
});

describe('audit_logs (functions only)', () => {
  test('admin can read', async () => {
    await assertSucceeds(getDoc(doc(adminCtx(), 'audit_logs', 'a1')));
  });
  test('non-admin cannot read', async () => {
    await assertFails(getDoc(doc(farmerCtx(), 'audit_logs', 'a1')));
  });
  test('nobody can write from a client', async () => {
    await assertFails(addDoc(collection(adminCtx(), 'audit_logs'), { action: 'x' }));
    await assertFails(addDoc(collection(farmerCtx(), 'audit_logs'), { action: 'x' }));
  });
});

describe.each(['commodities', 'markets'])('%s (catalog, functions-only writes)', (name) => {
  test('signed-in user can read', async () => {
    await assertSucceeds(getDoc(doc(farmerCtx(), name, 'x')));
  });
  test('unauthenticated cannot read', async () => {
    await assertFails(getDoc(doc(anonCtx(), name, 'x')));
  });
  test('no client writes, not even admin (goes through upsertCatalog)', async () => {
    await assertFails(setDoc(doc(farmerCtx(), name, 'x'), { active: true }));
    await assertFails(setDoc(doc(adminCtx(), name, 'x'), { active: true }));
  });
});

describe('price_reports (functions-only writes)', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'price_reports', 'mine'), { reporterId: FARMER_UID, price: 50 });
      await setDoc(doc(ctx.firestore(), 'price_reports', 'theirs'), { reporterId: 'other1', price: 50 });
    });
  });
  test('reporter can read own report', async () => {
    await assertSucceeds(getDoc(doc(farmerCtx(), 'price_reports', 'mine')));
  });
  test('cannot read other users reports (reporterId is not shared)', async () => {
    await assertFails(getDoc(doc(farmerCtx(), 'price_reports', 'theirs')));
  });
  test('admin can read any report', async () => {
    await assertSucceeds(getDoc(doc(adminCtx(), 'price_reports', 'theirs')));
  });
  test('no client writes: not even official-looking ones or admin', async () => {
    await assertFails(
      addDoc(collection(farmerCtx(), 'price_reports'), {
        reporterId: FARMER_UID, source: 'official', price: 1,
      }),
    );
    await assertFails(updateDoc(doc(farmerCtx(), 'price_reports', 'mine'), { price: 1 }));
    await assertFails(setDoc(doc(adminCtx(), 'price_reports', 'x'), { price: 1 }));
  });
});

describe('locked collections (until their build step)', () => {
  const locked = [ 'listings', 'inquiries', 'alerts',
    'abuse_reports', 'random_collection',
  ];
  test.each(locked)('%s: no client read or write', async (name) => {
    await assertFails(getDoc(doc(farmerCtx(), name, 'x')));
    await assertFails(setDoc(doc(farmerCtx(), name, 'x'), { a: 1 }));
    await assertFails(getDoc(doc(adminCtx(), name, 'x')));
    await assertFails(setDoc(doc(adminCtx(), name, 'x'), { a: 1 }));
  });
});
