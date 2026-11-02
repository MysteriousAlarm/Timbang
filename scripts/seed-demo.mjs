#!/usr/bin/env node
// EMULATOR ONLY: seeds illustrative commodities and markets, all marked isDemo: true.
// These are placeholders until the official DA / DAR / NVAT lists arrive. Replace them
// from the admin dashboard (CSV import), then use "Remove demo data".
//
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run seed:demo
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Refusing to run: set FIRESTORE_EMULATOR_HOST (emulator only).');
  process.exit(1);
}
initializeApp({ projectId: 'demo-timbang' });
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
process.exit(0);
