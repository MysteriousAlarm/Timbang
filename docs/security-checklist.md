# Security checklist (OWASP MASVS v2, mobile app) and backend controls

Status for TIMBANG v0.1.0. ✅ done, ⚠️ partial / configuration needed at deploy, ⏳ later.

## MASVS

| Control | Requirement | Status | Evidence |
|---|---|---|---|
| MASVS-STORAGE-1 | Sensitive data stored securely | ✅ | Only the Firestore offline cache (prices, own data); no tokens/secrets in app storage |
| MASVS-STORAGE-2 | No sensitive data leaks (backups, logs) | ✅ | `allowBackup=false`; no PII in logs; no analytics |
| MASVS-CRYPTO-1/2 | Strong crypto, proper key management | ✅ | TLS by Firebase; HMAC-SHA256 for the SMS webhook; secret in Secret Manager |
| MASVS-AUTH-1 | Secure authentication | ✅ | Firebase phone OTP; ID tokens verified by rules/functions |
| MASVS-AUTH-2 | Authorization enforced server-side | ✅ | Custom-claim roles, Firestore/Storage rules, `requireAdmin` (103 rules tests, integration tests) |
| MASVS-AUTH-3 | Sensitive operations need extra checks | ⚠️ | Admin actions audited; account deletion asks confirmation. Re-auth for admins: later |
| MASVS-NETWORK-1 | Secure traffic | ✅ | HTTPS only; cleartext allowed only in the debug manifest (emulators) |
| MASVS-NETWORK-2 | Certificate pinning | ⏳ | Not used (Google-managed endpoints); documented risk |
| MASVS-PLATFORM-1 | Safe IPC / intents | ✅ | Only `tel:` / `sms:` intents via url_launcher |
| MASVS-PLATFORM-2 | Safe WebViews | ✅ | No WebViews |
| MASVS-PLATFORM-3 | Safe UI (no sensitive data in screenshots/notifications) | ✅ | Push messages carry no phone numbers |
| MASVS-CODE-1 | Up-to-date platform | ✅ | minSdk 23, current Flutter stable |
| MASVS-CODE-2 | Update / dependency hygiene | ✅ | Dependabot (`.github/dependabot.yml`), `npm audit` in CI |
| MASVS-CODE-3 | Input validation | ✅ | Client validation mirrors rules; rules + functions validate types, ranges, enums, lengths |
| MASVS-CODE-4 | No debug code in release | ✅ | Emulator connection only in debug (`USE_EMULATORS` defaults to debug) |
| MASVS-RESILIENCE-1..4 | Anti-tampering / integrity | ⚠️ | App Check (Play Integrity) wired; enable enforcement after registering |
| MASVS-PRIVACY-1 | Data minimization | ✅ | Rules reject any extra profile field |
| MASVS-PRIVACY-2 | Transparency | ✅ | RA 10173 notice at signup, "Aking data" screen |
| MASVS-PRIVACY-3 | User control (access, delete) | ✅ | `exportMyData`, `deleteMyAccount` with cleanup |

## Backend checklist

- [x] Firestore rules deny by default; tests for every collection (`tests/rules`)
- [x] Storage rules: owner path, image types, < 1 MB
- [x] Only Cloud Functions write `price_board`, `audit_logs`, role claims, price reports
- [x] Rate limits: reports (20/h + duplicate), inquiries (10/h + per listing), SMS (10/h per number)
- [x] Moderation + abuse reporting; audit log for sensitive actions
- [x] Web hosting security headers (`firebase.json`: nosniff, frame deny, referrer, permissions, HSTS)
- [ ] Deploy: `firebase functions:secrets:set SMS_WEBHOOK_SECRET`
- [ ] Deploy: register App Check (Play Integrity, reCAPTCHA v3), then `ENFORCE_APP_CHECK=true`
- [ ] Deploy: restrict the Firebase API keys (Android package + SHA, web domains)
- [ ] Deploy: budget alert on the Blaze plan
- [ ] Keep the admin list short; dedicated admin SIM
