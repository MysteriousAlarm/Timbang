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

describe('listings (Step 5)', () => {
  const DAY = 24 * 60 * 60 * 1000;
  async function seedWorld({ role = 'farmer', status = 'active' } = {}) {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', FARMER_UID), {
        name: 'Juan Dela Cruz', phone: FARMER_PHONE, municipality: 'Bayombong',
        role, verified: false, status, createdAt: new Date(), consentAt: new Date(),
      });
      await setDoc(doc(db, 'commodities', 'kamatis'), { nameFil: 'Kamatis', unit: 'kg', active: true });
    });
  }
  function listing(over = {}) {
    return {
      farmerId: FARMER_UID, farmerName: 'Juan Dela Cruz', farmerPhone: FARMER_PHONE,
      commodityId: 'kamatis', quantity: 50, unit: 'kg', askingPrice: 55, municipality: 'Bayombong',
      harvestDate: new Date(), photoUrls: [], status: 'active',
      createdAt: serverTimestamp(), expiresAt: new Date(Date.now() + 14 * DAY), ...over,
    };
  }
  async function seedListing(over = {}) {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'listings', 'L1'), {
        ...listing(), createdAt: new Date(), ...over,
      });
    });
  }

  test('active farmer can post a valid listing', async () => {
    await seedWorld();
    await assertSucceeds(setDoc(doc(farmerCtx(), 'listings', 'L1'), listing()));
  });
  test('buyers cannot post listings', async () => {
    await seedWorld({ role: 'buyer' });
    await assertFails(setDoc(doc(farmerCtx(), 'listings', 'L1'), listing()));
  });
  test('suspended farmer cannot post', async () => {
    await seedWorld({ status: 'suspended' });
    await assertFails(setDoc(doc(farmerCtx(), 'listings', 'L1'), listing()));
  });
  test.each([
    ['someone else as farmer', { farmerId: 'other1' }],
    ['fake contact phone', { farmerPhone: '+639990000000' }],
    ['fake name', { farmerName: 'Iba' }],
    ['unknown commodity', { commodityId: 'ginto' }],
    ['zero quantity', { quantity: 0 }],
    ['negative price', { askingPrice: -1 }],
    ['bad unit', { unit: 'sako' }],
    ['outside Nueva Vizcaya', { municipality: 'Makati' }],
    ['too many photos', { photoUrls: ['a', 'b', 'c', 'd'] }],
    ['not active', { status: 'sold' }],
    ['expiry too far', { expiresAt: new Date(Date.now() + 60 * DAY) }],
    ['expiry in the past', { expiresAt: new Date(Date.now() - DAY) }],
    ['extra field', { verified: true }],
    ['long note', { note: 'x'.repeat(281) }],
  ])('rejects %s', async (_name, over) => {
    await seedWorld();
    await assertFails(setDoc(doc(farmerCtx(), 'listings', 'L1'), listing(over)));
  });
  test('signed-in users can read listings; anonymous cannot', async () => {
    await seedWorld(); await seedListing();
    await assertSucceeds(getDoc(doc(otherCtx(), 'listings', 'L1')));
    await assertFails(getDoc(doc(anonCtx(), 'listings', 'L1')));
  });
  test('owner can mark sold and edit price', async () => {
    await seedWorld(); await seedListing();
    await assertSucceeds(updateDoc(doc(farmerCtx(), 'listings', 'L1'), {
      status: 'sold', askingPrice: 50, updatedAt: serverTimestamp(),
    }));
  });
  test('owner cannot change commodity or owner, others cannot edit', async () => {
    await seedWorld(); await seedListing();
    await assertFails(updateDoc(doc(farmerCtx(), 'listings', 'L1'), { commodityId: 'kamatis', farmerId: 'x', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(otherCtx(), 'listings', 'L1'), { status: 'sold', updatedAt: serverTimestamp() }));
  });
  test('moderated listing cannot be revived by the owner', async () => {
    await seedWorld(); await seedListing({ status: 'removed', moderatedAt: new Date() });
    await assertFails(updateDoc(doc(farmerCtx(), 'listings', 'L1'), { status: 'active', updatedAt: serverTimestamp() }));
  });
  test('renewing an expired listing needs a new valid expiry', async () => {
    await seedWorld(); await seedListing({ status: 'expired', expiresAt: new Date(Date.now() - DAY) });
    await assertFails(updateDoc(doc(farmerCtx(), 'listings', 'L1'), { status: 'active', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(farmerCtx(), 'listings', 'L1'), {
      status: 'active', expiresAt: new Date(Date.now() + 14 * DAY), updatedAt: serverTimestamp(),
    }));
  });
  test('no deletes', async () => {
    await seedWorld(); await seedListing();
    await assertFails(deleteDoc(doc(farmerCtx(), 'listings', 'L1')));
  });
});

describe('inquiries (Step 6)', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'inquiries', 'Q1'), {
        listingId: 'L1', farmerId: FARMER_UID, buyerId: 'other1', buyerName: 'Bea',
        buyerPhone: '+639170000000', message: 'Available pa?', status: 'new', createdAt: new Date(),
      });
    });
  });
  const strangerCtx = () => env.authenticatedContext('stranger').firestore();
  test('farmer, buyer and admin can read; strangers cannot', async () => {
    await assertSucceeds(getDoc(doc(farmerCtx(), 'inquiries', 'Q1')));
    await assertSucceeds(getDoc(doc(otherCtx(), 'inquiries', 'Q1')));
    await assertSucceeds(getDoc(doc(adminCtx(), 'inquiries', 'Q1')));
    await assertFails(getDoc(doc(strangerCtx(), 'inquiries', 'Q1')));
    await assertFails(getDoc(doc(anonCtx(), 'inquiries', 'Q1')));
  });
  test('farmer marks read or closed', async () => {
    await assertSucceeds(updateDoc(doc(farmerCtx(), 'inquiries', 'Q1'), { status: 'read', updatedAt: serverTimestamp() }));
  });
  test('buyer can only close', async () => {
    await assertFails(updateDoc(doc(otherCtx(), 'inquiries', 'Q1'), { status: 'read', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(otherCtx(), 'inquiries', 'Q1'), { status: 'closed', updatedAt: serverTimestamp() }));
  });
  test('nobody edits the message or contact; no client creates/deletes', async () => {
    await assertFails(updateDoc(doc(farmerCtx(), 'inquiries', 'Q1'), { message: 'x', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(otherCtx(), 'inquiries', 'Q1'), { buyerPhone: '+639999999999', updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(otherCtx(), 'inquiries', 'Q2'), { farmerId: FARMER_UID, buyerId: 'other1', message: 'x' }));
    await assertFails(deleteDoc(doc(farmerCtx(), 'inquiries', 'Q1')));
  });
});

describe('alerts (Step 7)', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'commodities', 'kamatis'), { nameFil: 'Kamatis' });
      await setDoc(doc(db, 'markets', 'bpm'), { name: 'BPM' });
      await setDoc(doc(db, 'alerts', 'A1'), {
        userId: FARMER_UID, commodityId: 'kamatis', marketId: 'bpm', threshold: 60,
        direction: 'above', active: true, createdAt: new Date(),
      });
    });
  });
  const alert = (over = {}) => ({
    userId: FARMER_UID, commodityId: 'kamatis', marketId: 'bpm', threshold: 60,
    direction: 'above', active: true, createdAt: serverTimestamp(), ...over,
  });
  test('user creates own alert', async () => {
    await assertSucceeds(setDoc(doc(farmerCtx(), 'alerts', 'A2'), alert()));
  });
  test.each([
    ['for someone else', { userId: 'other1' }],
    ['unknown market', { marketId: 'nope' }],
    ['bad direction', { direction: 'sideways' }],
    ['zero threshold', { threshold: 0 }],
    ['server field', { lastTriggeredMedian: 5 }],
  ])('rejects %s', async (_n, over) => {
    await assertFails(setDoc(doc(farmerCtx(), 'alerts', 'A2'), alert(over)));
  });
  test('owner reads, edits, deletes; others cannot read', async () => {
    await assertSucceeds(getDoc(doc(farmerCtx(), 'alerts', 'A1')));
    await assertFails(getDoc(doc(otherCtx(), 'alerts', 'A1')));
    await assertSucceeds(updateDoc(doc(farmerCtx(), 'alerts', 'A1'), { active: false, threshold: 70, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(farmerCtx(), 'alerts', 'A1'), { lastTriggeredAt: new Date(), updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(otherCtx(), 'alerts', 'A1')));
    await assertSucceeds(deleteDoc(doc(farmerCtx(), 'alerts', 'A1')));
  });
});

describe('locked collections (until their build step)', () => {
  const locked = [
    'abuse_reports', 'random_collection',
  ];
  test.each(locked)('%s: no client read or write', async (name) => {
    await assertFails(getDoc(doc(farmerCtx(), name, 'x')));
    await assertFails(setDoc(doc(farmerCtx(), name, 'x'), { a: 1 }));
    await assertFails(getDoc(doc(adminCtx(), name, 'x')));
    await assertFails(setDoc(doc(adminCtx(), name, 'x'), { a: 1 }));
  });
});
