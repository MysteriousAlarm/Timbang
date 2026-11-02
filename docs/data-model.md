# TIMBANG data model (Firestore)

Source of truth: `CLAUDE.md` Section 7. This file tracks what is **implemented** and how the
rules enforce it. Update it whenever the model or rules change.

## Status by collection

| Collection | Status | Client read | Client write |
|---|---|---|---|
| `users/{uid}` | Step 1, live | owner, admin (claim) | owner create/update with field allowlist; no delete (use `deleteMyAccount`) |
| `price_board/{commodityId_marketId}` | rules live, data from Step 3 | any signed-in user | **none** (Cloud Functions only) |
| `audit_logs/{id}` | live | admin (claim) | **none** (Cloud Functions only) |
| `commodities`, `markets` | locked until Step 2 | none | none |
| `price_reports` | locked until Step 3 | none | none |
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

## `audit_logs/{id}`

`actorId`, `action` (`set_user_role`, `delete_account`), `targetPath`, `detail`, `timestamp`.
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
