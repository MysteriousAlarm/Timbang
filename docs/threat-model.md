# Project TIMBANG: Threat model (STRIDE)

Scope: Flutter app (Android) and website/admin (Flutter web), Firebase Auth (phone OTP),
Cloud Firestore, Cloud Storage, Cloud Functions (asia-southeast1), FCM, SMS gateway (mock).
Version: first build v0.1.0. Reviewed for CS PC 7 Information Assurance and Technology.

## Assets

| Asset | Why it matters |
|---|---|
| Price board (medians, confidence) | Farmers decide when and where to sell from it; a manipulated price harms them |
| Personal data: name, phone, municipality (RA 10173) | Only PII collected; phone numbers are shared with buyers when needed |
| Role claims (reporter, admin) | Reporter reports outweigh community ones; admins moderate and import official data |
| Listings and inquiries | Direct buyer–farmer contact; scams and spam risk |
| Audit log | Evidence of who changed roles, data and moderation |
| SMS webhook secret, service-account keys | Would allow forged SMS or full backend access |

## Trust boundaries

1. Phone (untrusted client) → Firebase (Auth, Firestore rules, callable Functions)
2. Website / admin browser (untrusted client) → same backend; admin rights only via the role claim
3. SMS gateway (external) → `smsWebhook` (HTTP)
4. Cloud Functions (trusted, Admin SDK) → Firestore / Storage / FCM

## STRIDE analysis

| # | Threat | Example | Mitigations (where in code) | Residual risk |
|---|---|---|---|---|
| S1 | **Spoofing** a user | Sign in as someone else's number | Firebase phone OTP; profile `phone` must equal the verified token phone (`firestore.rules` users create) | SIM swap / OTP theft is outside app control |
| S2 | Spoofing a role | Client writes `role: admin` | Roles are custom claims set only by admin-only `setUserRole`; rules never read the Firestore role for privileges; test "client cannot self-assign role" | Compromised admin phone |
| S3 | Spoofing the app | Scripted client calling functions | App Check (Play Integrity / reCAPTCHA v3) with `ENFORCE_APP_CHECK` on all callables | Enforcement switched on after registration |
| S4 | Spoofing the SMS gateway | Forged webhook calls | HMAC-SHA256 over the raw body, constant-time compare, fails closed without a secret (`functions/src/sms/gateway.ts`) | Secret leak; rotate via Secret Manager |
| T1 | **Tampering** with prices | Fake low price to trick farmers | Reports only via `submitPriceReport` (server sets source tier); median not mean; 30% outlier rule; confidence labels; admin reject/restore; rejected price removed from board | Coordinated reports from many real accounts (moderation + low confidence) |
| T2 | Tampering with the board | Client writes `price_board` | Rules: no client writes to `price_board`, `audit_logs`, `price_reports`, catalog | — |
| T3 | Tampering with listings | Edit someone else's listing, fake contact | Rules: owner-only, field allowlist, contact must equal own profile, moderated listings final | — |
| T4 | Malicious upload | Large or non-image files | Storage rules: owner path, `image/jpeg|png|webp`, < 1 MB; client compression | Image content itself (moderation via abuse reports) |
| R1 | **Repudiation** | Admin denies changing a role or removing a listing | Every admin callable writes `audit_logs` (functions only, admin read-only); Admin → Audit log | Logs are not tamper-evident beyond Firestore IAM |
| I1 | **Information disclosure**: phone numbers | Scraping contact numbers | Listings/inquiries readable by signed-in users only; users docs owner/admin only; inquiries only to the two parties | Signed-in scraping (rate limits on inquiries; account suspension) |
| I2 | Disclosure via SMS | Reply reveals other people's data | Replies contain only prices; numbers hashed for rate limits and masked in logs | — |
| I3 | Disclosure via push | Phone numbers in notifications | Push text has buyer name and commodity only | — |
| I4 | Disclosure of secrets | Keys in the repo | No secrets in client or repo; `.gitignore` for service accounts/env; SMS secret in Secret Manager; Firebase web config is public by design | Restrict API keys in Google Cloud |
| I5 | Device data | Backups expose cached data | `android:allowBackup="false"` | Rooted devices |
| D1 | **Denial of service**: report flooding | Bot submits thousands of reports | 20 reports/hour/user + 10-minute duplicate block; App Check; `maxInstances` caps | Many accounts |
| D2 | Inquiry / SMS flooding | Spam farmers or burn SMS budget | 10 inquiries/hour, one per listing per 6 h; SMS 10/hour per number; budget alert | Distributed numbers |
| E1 | **Elevation of privilege** | Farmer calls admin functions | `requireAdmin` on every admin callable (unit + integration tests with non-admin callers) | — |
| E2 | Suspended user keeps acting | Banned user posts again | `status` checked by rules (listings, profile) and functions (reports, inquiries) | Existing ID token until refresh |

## Privacy (RA 10173) controls

- Data minimization: only name, phone, municipality (rules reject extra fields).
- Consent notice at signup, `consentAt` stored.
- Right of access: Profile → "Tingnan / kopyahin ang aking data" (`exportMyData`).
- Right to erasure: Profile → "Burahin ang account" (`deleteMyAccount`) deletes profile, auth
  user, alerts and inquiries, removes listings and photos, anonymizes price reports.
- No analytics SDK; no PII in logs (numbers masked, audit uses uids).

## Out of scope / accepted for the pilot

- No end-to-end encryption of inquiries (one short message, visible to the two parties and admins).
- Admin accounts are protected by phone OTP only; use a dedicated SIM and keep the admin list short.
