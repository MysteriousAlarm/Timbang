#!/usr/bin/env node
// Seeds illustrative commodities, markets and price reports, ALL marked isDemo: true
// (shown with DEMO badges and a "not real prices" banner). Placeholders until the official
// DA / DAR / NVAT lists arrive: replace them via the admin dashboard, then "Remove demo data".
//
// Emulator:      FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run seed:demo
// Real project (for a prototype demo, explicit opt-in):
//   GOOGLE_APPLICATION_CREDENTIALS=/path/outside/repo/sa.json \
//   SEED_REAL_PROJECT=<project-id> npm run seed:demo
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const real = process.env.SEED_REAL_PROJECT;
if (!process.env.FIRESTORE_EMULATOR_HOST && !real) {
  console.error('Set FIRESTORE_EMULATOR_HOST (emulator) or SEED_REAL_PROJECT=<project-id>.');
  process.exit(1);
}
if (real) console.log(`Seeding DEMO data into REAL project "${real}" (all items isDemo: true).`);
initializeApp({ projectId: real || 'demo-timbang' });
const db = getFirestore();

const commodities = [
  ['kamatis', 'Kamatis', 'Tomato', 'kg', 'Lowland vegetables'],
  ['talong', 'Talong', 'Eggplant', 'kg', 'Lowland vegetables'],
  ['ampalaya', 'Ampalaya', 'Bitter gourd', 'kg', 'Lowland vegetables'],
  ['sitaw', 'Sitaw', 'String beans', 'bundle', 'Lowland vegetables'],
  ['okra', 'Okra', 'Okra', 'kg', 'Lowland vegetables'],
  ['kalabasa', 'Kalabasa', 'Squash', 'kg', 'Lowland vegetables'],
  ['pechay', 'Pechay', 'Pechay (bok choy)', 'bundle', 'Lowland vegetables'],
  ['repolyo', 'Repolyo', 'Cabbage', 'kg', 'Highland vegetables'],
  ['karot', 'Karot', 'Carrots', 'kg', 'Highland vegetables'],
];
const markets = [
  ['bayombong-public-market', 'Bayombong Public Market', 'Bayombong', 'public_market'],
  ['solano-public-market', 'Solano Public Market', 'Solano', 'public_market'],
  ['bambang-public-market', 'Bambang Public Market', 'Bambang', 'public_market'],
  ['nvat-bambang', 'NVAT Trading Post (Bambang)', 'Bambang', 'trading_post'],
];

const batch = db.batch();
for (const [id, nameFil, nameEn, unit, category] of commodities) {
  batch.set(db.doc(`commodities/${id}`), {
    nameFil, nameEn, unit, category, active: true, isDemo: true,
    updatedAt: FieldValue.serverTimestamp(),
  });
}
for (const [id, name, municipality, type] of markets) {
  batch.set(db.doc(`markets/${id}`), {
    name, municipality, type, active: true, isDemo: true,
    updatedAt: FieldValue.serverTimestamp(),
  });
}
await batch.commit();
console.log(`Seeded ${commodities.length} demo commodities and ${markets.length} demo markets.`);

// Illustrative price reports (isDemo). With the Functions emulator running, the
// onPriceReportCreated trigger turns these into price_board entries (also isDemo).
const H = 60 * 60 * 1000;
const now = Date.now();
// [commodity, market, price, source, hoursAgo]
const reports = [
  ['kamatis', 'bayombong-public-market', 58, 'reporter', 30],
  ['kamatis', 'bayombong-public-market', 60, 'reporter', 26],
  ['kamatis', 'bayombong-public-market', 64, 'reporter', 3],
  ['kamatis', 'bayombong-public-market', 66, 'community', 2],
  ['kamatis', 'bayombong-public-market', 63, 'community', 1],
  ['repolyo', 'bayombong-public-market', 45, 'reporter', 29],
  ['repolyo', 'bayombong-public-market', 44, 'reporter', 5],
  ['sitaw', 'bayombong-public-market', 30, 'community', 4],
  ['karot', 'bayombong-public-market', 70, 'reporter', 31],
  ['karot', 'bayombong-public-market', 62, 'reporter', 6],
  ['talong', 'bayombong-public-market', 55, 'reporter', 7],
  ['kamatis', 'solano-public-market', 61, 'community', 8],
  ['kamatis', 'nvat-bambang', 52, 'reporter', 9],
  ['repolyo', 'nvat-bambang', 38, 'reporter', 10],
  ['karot', 'solano-public-market', 68, 'reporter', 40],
];
const units = Object.fromEntries(commodities.map(([id, , , unit]) => [id, unit]));
// Older reports first so each trigger sees the history it needs for the trend.
for (const [commodityId, marketId, price, source, hoursAgo] of reports.sort((a, b) => b[4] - a[4])) {
  await db.collection('price_reports').add({
    commodityId, marketId, price, unit: units[commodityId],
    reporterId: 'demo-seed', reporterRole: 'demo', source, status: 'valid', isDemo: true,
    timestamp: new Date(now - hoursAgo * H),
  });
}
console.log(`Seeded ${reports.length} demo price reports (needs the Functions emulator for the board).`);
process.exit(0);
