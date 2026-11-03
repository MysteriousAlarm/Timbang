#!/usr/bin/env node
// Starts the Firebase emulators reachable from a PHONE on the same Wi-Fi (development only).
// It writes .firebase.lan.json (gitignored): firebase.json with every emulator bound to 0.0.0.0.
//   npm run emulators:lan
// Then build the debug APK with --dart-define=EMULATOR_HOST=<this PC's Wi-Fi IP>.
import { readFileSync, writeFileSync } from 'fs';
import { spawnSync } from 'child_process';

const cfg = JSON.parse(readFileSync(new URL('../firebase.json', import.meta.url)));
for (const [name, value] of Object.entries(cfg.emulators)) {
  if (value && typeof value === 'object' && 'port' in value) value.host = '0.0.0.0';
  if (name === 'ui') value.host = '0.0.0.0';
}
writeFileSync(new URL('../.firebase.lan.json', import.meta.url), JSON.stringify(cfg, null, 2));
console.log('Emulators will listen on all network interfaces (LAN). Do not use on public Wi-Fi.');
const r = spawnSync(
  'firebase',
  ['emulators:start', '--config', '.firebase.lan.json', '--project', 'demo-timbang', '--import=./emulator-data', '--export-on-exit'],
  { stdio: 'inherit', shell: true },
);
process.exit(r.status ?? 1);
