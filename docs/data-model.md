# TIMBANG data model (Firestore)

Source of truth: `CLAUDE.md` Section 7. This file tracks what is **implemented** and how the
rules enforce it. Update it whenever the model or rules change.

## Status by collection

| Collection | Status | Client read | Client write |
|---|---|---|---|
| `users/{uid}` | Step 1, live | owner, admin (claim) | owner create/update with field allowlist; no delete (use `deleteMyAccount`) |
| `price_board/{commodityId_marketId}` | Step 3, live | any signed-in user | **none** (`onPriceReportCreated` / `importOfficialPrices`) |
| `audit_logs/{id}` | live | admin (claim) | **none** (Cloud Functions only) |
| `commodities`, `markets` | Step 2, live | any signed-in user | **none** (`upsertCatalog` / `clearDemoCatalog`, admin only) |
| `price_reports` | Step 3, live | admin; reporter reads own | **none** (`submitPriceReport` / `importOfficialPrices`) |
| `listings` | locked until Step 5 | none | none |
| `inquiries` | locked until Step 6 | none | none |
| `alerts` | locked until Step 7 | none | none |
| `abuse_reports` | locked until Step 8 | none | none |

Anything not listed is denied (`match /{document=**}` → false).

## `users/{uid}`

| Field | Type | Who writes | Notes |
|---|---|---|---|
| `name` | string, 2..80 chars | owner | personal data |
| `phone` | string, E.164 | owner at create | must equal `request.auth.token.phone_number`; immutable |
| `municipality` | one of the 15 Nueva Vizcaya municipalities | owner | personal data |
| `role` | farmer \| buyer \| reporter \| admin | owner at create (farmer/buyer only); then `setUserRole` | **display mirror only**; authorization uses the custom claim |
| `verified` | bool | `setUserRole` (true for reporter/admin) | client must create as `false` |
| `status` | active \| suspended | server only | suspended users cannot update their profile |
| `createdAt`, `consentAt` | timestamp | owner at create | must equal `request.time` (server timestamp); `consentAt` records RA 10173 consent |
| `updatedAt` | timestamp | owner / functions | must equal `request.time` when set by owner |
| `fcmTokens` | list, max 10 | owner | used from Step 6 |
| `reporterScore`, `assignedMarketIds` | number, list | server only | reporters, from Step 3/8 |

## `commodities/{id}` and `markets/{id}` (Step 2)

The lists are **data, not code**. They are managed by admins in the web dashboard (form or CSV
import), so the official DA / DAR / NVAT lists can replace the demo lists without a code change.

- Document ID = a stable slug (`kamatis`, `bayombong-public-market`), used as the CSV `id` column.
  Importing a row with an existing ID updates it.
- `commodities`: `nameFil` (1-60), `nameEn` (1-60), `unit` (kg | bundle | piece), `category`
  (free text 1-40, e.g. "Lowland vegetables"), `active`, `isDemo`, `updatedAt`.
- `markets`: `name` (2-80), `municipality` (one of the 15), `type` (public_market | trading_post |
  farmgate_area), `active`, `isDemo`, `updatedAt`.
- Items are never deleted, only set `active: false`, so old price reports keep their references.
  The exception is seeded demo data (`isDemo: true`), removed with `clearDemoCatalog`.
- Imports are all-or-nothing (max 500 rows per call); the server re-validates every row and
  returns per-row errors. Every write is recorded in `audit_logs`.
- CSV templates: `docs/templates/commodities.csv`, `docs/templates/markets.csv`.

## `price_reports/{id}` (Step 3)

`commodityId`, `marketId`, `price` (0.01-100000, 2 decimals), `unit` (copied from the commodity),
`reporterId`, `reporterRole`, `source` (official | reporter | community), `timestamp`,
`status` (valid | outlier | rejected), `isDemo`, optional `batchId` + `sourceNote` (official imports).

- Submitted only through `submitPriceReport` (any signed-in, active user). The **source tier is
  set by the server from the role claim**: reporter/admin -> `reporter`, everyone else -> `community`.
  Official reports only come from the admin-only `importOfficialPrices`.
- Reporters with `assignedMarketIds` can only report for those markets.
- Rate limits: 20 reports per user per hour; the same user + commodity + market at most once per
  10 minutes (`functions/src/config.ts`).
- `status` is maintained by the board function (valid/outlier); `rejected` is an admin decision (Step 8).

## `price_board/{commodityId}_{marketId}` (Step 3)

`commodityId`, `marketId`, `unit`, `medianPrice`, `confidence` (high | medium | low), `reportCount`,
`trend` (up | down | flat), `previousMedian`, `sources` {official, reporter, community counts},
`isDemo`, `latestReportAt`, `updatedAt`.

Computed by `functions/src/confidence.ts` (pure, unit-tested) on every new report:
1. Reports from the last 24 h, excluding `rejected`. Median, never mean or latest.
2. Non-official reports > 30% from the median become `outlier`; median recomputed. Official
   reports are never outliers. If every report would be an outlier, none are marked.
3. High: any official, or 3+ reports within 15% of the median incl. a verified reporter.
   Medium: verified reporter report(s) without that agreement. Low: community only.
4. Trend vs the previous 24 h median; within ±3% is flat.
5. No reports in 24 h: the entry is left as is; the UI shows it as stale with its age.
6. `users.reporterScore` = share of a reporter's reports within 15% of the median.

## `audit_logs/{id}`

`actorId`, `action` (`set_user_role`, `delete_account`, `upsert_commodities`, `upsert_markets`,
`clear_demo_commodities`, `clear_demo_markets`, `import_official_prices`), `targetPath`, `detail`, `timestamp`.
No personal data (uids and paths only).

## Roles (custom claims)

- Claim key: `role`. Set only by the admin-only callable `setUserRole({ uid, role })`
  (region `asia-southeast1`), which also mirrors the role into `users/{uid}` and writes an audit log.
- An admin cannot remove their own admin role (prevents lockout).
- The very first admin is bootstrapped locally with `scripts/set-admin.mjs` (never deployed).
- Clients re-read the ID token whenever the mirrored role changes, so role changes apply
  without signing out.

## Storage

`listings/{uid}/{listingId}/{file}`: signed-in read; owner write; `image/jpeg|png|webp` only;
under 1 MB. Everything else denied.
