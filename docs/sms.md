# SMS price query (Step 9)

For people on basic phones. A user texts a command; TIMBANG replies with the latest median,
unit, confidence and age. Replies use GSM-7 characters only (`P64.00`, not `₱`) so each reply
fits in one 160-character SMS.

| Text | Reply |
|---|---|
| `PRESYO KAMATIS BAYOMBONG` | `TIMBANG: Kamatis: Bayombong Public Market P64.00/kilo, Mataas, 2 oras na. Median ng ulat.` |
| `PRESYO KAMATIS` | the two freshest markets |
| `KAMATIS SOLANO`, `PRICE TOMATO SOLANO` | also understood (Filipino or English names, accents and punctuation ignored) |
| `TULONG`, `HELP`, anything unclear | short help: `I-text ang PRESYO <gulay> <bayan>...` |

Stale prices (no report in 24 h) say `LUMA NA`. Demo data is prefixed `[DEMO, hindi totoo]`.

## Architecture

```
gateway (Semaphore / Globe Labs)  --POST-->  smsWebhook (Cloud Function)
                                              1. gateway.verifyWebhook(req)   -> 401 if not authentic
                                              2. rate limit: 10/hour per number (sms_rate/{sha256 hash})
                                              3. parseSms + price_board lookup (functions/src/sms/query.ts)
                                              4. gateway.send(from, reply)
```

- `functions/src/sms/gateway.ts`: `SmsGateway` interface (`send(to, text)`, `verifyWebhook(req)`)
  and `MockSmsGateway` (JSON `{from, text}`, HMAC-SHA256 of the raw body in `x-timbang-signature`).
- Security: signatures are checked in constant time and **fail closed** (no secret means no
  request is accepted). Raw phone numbers are never stored (the rate-limit key is a hash) and
  are masked in logs. Replies never contain personal data. `sms_rate` is closed to clients.
- The secret lives in **Secret Manager**: `firebase functions:secrets:set SMS_WEBHOOK_SECRET`.
  The emulator uses `functions/.secret.local` (gitignored, created by `scripts/ensure-dev-secret.mjs`).
- Admin → **SMS na presyo** runs the same parser and data with no gateway and no cost, for demos.

## Adding the real gateway (after Section 15 #2 is decided)

1. Create `functions/src/sms/semaphore.ts` (or `globelabs.ts`) implementing `SmsGateway`:
   - `send`: call the provider's send API with the API key from another secret
     (`defineSecret('SEMAPHORE_API_KEY')`).
   - `verifyWebhook`: check the provider's own authenticity mechanism (shared token or signature)
     and map its payload to `{from, text}`.
2. Return it from `smsGateway()` in `functions/src/index.ts` (e.g. by `SMS_PROVIDER`).
3. Point the provider's inbound webhook to `https://asia-southeast1-<project>.cloudfunctions.net/smsWebhook`.
4. Decide who pays for SMS during the pilot (Section 15 #2) and set a budget alert.
