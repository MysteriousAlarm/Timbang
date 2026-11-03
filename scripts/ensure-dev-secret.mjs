#!/usr/bin/env node
// Creates functions/.secret.local (gitignored) for the EMULATOR only, so the SMS webhook has a
// signing secret in development and CI. Production uses Secret Manager:
//   firebase functions:secrets:set SMS_WEBHOOK_SECRET
import { existsSync, writeFileSync } from 'fs';
const path = new URL('../functions/.secret.local', import.meta.url);
if (!existsSync(path)) {
  writeFileSync(path, 'SMS_WEBHOOK_SECRET=dev-only-sms-secret\n');
  console.log('Created functions/.secret.local (emulator-only dev secret).');
}
