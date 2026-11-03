import { onCall } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { setGlobalOptions } from 'firebase-functions/v2';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { REGION } from './config';
import { auth, db, writeAudit } from './firebase';
import { setUserRoleHandler, RoleDeps } from './roles';
import { deleteMyAccountHandler } from './account';
import { CatalogDeps, clearDemoCatalogHandler, upsertCatalogHandler } from './catalog';
import { CalcReport } from './confidence';
import { expireListings } from './listings';
import { sendInquiryHandler } from './inquiries';
import { Alert, alertText, alertsToFire } from './alerts';
import { Notifier, PushMessage } from './notify';
import { getMessaging } from 'firebase-admin/messaging';
import {
  PriceStore,
  importOfficialPricesHandler,
  onReportCreated,
  submitPriceReportHandler,
} from './priceReports';

setGlobalOptions({ region: REGION, maxInstances: 5 });

const roleDeps: RoleDeps = {
  async getClaims(uid) {
    try {
      const user = await auth.getUser(uid);
      return user.customClaims ?? {};
    } catch {
      return null;
    }
  },
  async setClaims(uid, claims) {
    await auth.setCustomUserClaims(uid, claims);
  },
  async mirrorRole(uid, role, verified) {
    const ref = db.collection('users').doc(uid);
    const snap = await ref.get();
    if (!snap.exists) return false;
    await ref.update({ role, verified, updatedAt: FieldValue.serverTimestamp() });
    return true;
  },
  audit: writeAudit,
};

/** Admin-only callable: set a user's role custom claim. */
export const setUserRole = onCall((req) =>
  setUserRoleHandler(
    req.auth ? { uid: req.auth.uid, role: req.auth.token.role } : undefined,
    req.data,
    roleDeps,
  ),
);

/** Callable: the signed-in user deletes their own account (RA 10173). */
export const deleteMyAccount = onCall((req) =>
  deleteMyAccountHandler(req.auth ? { uid: req.auth.uid } : undefined, {
    deleteProfile: async (uid) => {
      await db.collection('users').doc(uid).delete();
    },
    deleteAuthUser: (uid) => auth.deleteUser(uid),
    audit: writeAudit,
  }),
);

const catalogDeps: CatalogDeps = {
  async upsert(kind, items) {
    // Firestore batches hold up to 500 writes; items are capped at 500 per call.
    const batch = db.batch();
    for (const { id, ...fields } of items) {
      batch.set(
        db.collection(kind).doc(id),
        { ...fields, isDemo: false, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
    await batch.commit();
  },
  async deleteDemo(kind) {
    const snap = await db.collection(kind).where('isDemo', '==', true).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    return snap.size;
  },
  audit: writeAudit,
};

const caller = (auth?: { uid: string; token: Record<string, unknown> }) =>
  auth ? { uid: auth.uid, role: auth.token.role } : undefined;

/** Admin-only callable: create/update commodities or markets (form edit or CSV import). */
export const upsertCatalog = onCall((req) =>
  upsertCatalogHandler(caller(req.auth), req.data, catalogDeps),
);

/** Admin-only callable: delete seeded demo commodities or markets. */
export const clearDemoCatalog = onCall((req) =>
  clearDemoCatalogHandler(caller(req.auth), req.data, catalogDeps),
);

const priceStore: PriceStore = {
  now: () => Date.now(),
  async getCommodity(id) {
    const d = (await db.doc(`commodities/${id}`).get()).data();
    return d ? { unit: String(d.unit), active: d.active !== false } : null;
  },
  async getMarket(id) {
    const d = (await db.doc(`markets/${id}`).get()).data();
    return d ? { active: d.active !== false } : null;
  },
  async getUser(uid) {
    const d = (await db.doc(`users/${uid}`).get()).data();
    return d
      ? { status: String(d.status ?? 'active'), assignedMarketIds: d.assignedMarketIds ?? [] }
      : null;
  },
  async reportsByUserSince(uid, sinceMs) {
    const snap = await db
      .collection('price_reports')
      .where('reporterId', '==', uid)
      .where('timestamp', '>', Timestamp.fromMillis(sinceMs))
      .get();
    return snap.docs.map((d) => ({
      commodityId: d.get('commodityId'),
      marketId: d.get('marketId'),
      timestamp: (d.get('timestamp') as Timestamp).toMillis(),
    }));
  },
  async addReports(reports) {
    const ids: string[] = [];
    for (let i = 0; i < reports.length; i += 450) {
      const batch = db.batch();
      for (const r of reports.slice(i, i + 450)) {
        const ref = db.collection('price_reports').doc();
        ids.push(ref.id);
        batch.set(ref, { ...r, timestamp: Timestamp.fromMillis(r.timestamp) });
      }
      await batch.commit();
    }
    return ids;
  },
  async reportsForPairSince(commodityId, marketId, sinceMs) {
    const snap = await db
      .collection('price_reports')
      .where('commodityId', '==', commodityId)
      .where('marketId', '==', marketId)
      .where('timestamp', '>', Timestamp.fromMillis(sinceMs))
      .get();
    return snap.docs.map((d): CalcReport => ({
      id: d.id,
      price: d.get('price'),
      source: d.get('source'),
      status: d.get('status'),
      timestamp: (d.get('timestamp') as Timestamp).toMillis(),
      isDemo: d.get('isDemo') === true,
    }));
  },
  async saveBoard(commodityId, marketId, unit, b) {
    const batch = db.batch();
    batch.set(db.doc(`price_board/${commodityId}_${marketId}`), {
      commodityId,
      marketId,
      unit,
      medianPrice: b.medianPrice,
      confidence: b.confidence,
      reportCount: b.reportCount,
      trend: b.trend,
      previousMedian: b.previousMedian,
      sources: b.sources,
      isDemo: b.isDemo,
      latestReportAt: Timestamp.fromMillis(b.latestReportAt),
      updatedAt: FieldValue.serverTimestamp(),
    });
    for (const u of b.statusUpdates) {
      batch.update(db.doc(`price_reports/${u.id}`), { status: u.status });
    }
    await batch.commit();
  },
  async getBoardMedian(commodityId, marketId) {
    const d = await db.doc(`price_board/${commodityId}_${marketId}`).get();
    return d.exists ? (d.get('medianPrice') as number) : null;
  },
  async boardUpdated(commodityId, marketId, unit, prev, board) {
    const snap = await db
      .collection('alerts')
      .where('commodityId', '==', commodityId)
      .where('marketId', '==', marketId)
      .where('active', '==', true)
      .get();
    if (snap.empty) return;
    const alerts: Alert[] = snap.docs.map((d) => ({
      id: d.id,
      userId: d.get('userId'),
      threshold: d.get('threshold'),
      direction: d.get('direction'),
    }));
    const fire = alertsToFire(alerts, prev, board.medianPrice);
    if (!fire.length) return;
    const [c, m] = await Promise.all([
      db.doc(`commodities/${commodityId}`).get(),
      db.doc(`markets/${marketId}`).get(),
    ]);
    const unitWord = unit === 'kg' ? 'kilo' : unit === 'bundle' ? 'tali' : 'piraso';
    for (const a of fire) {
      const text = alertText(
        a,
        c.get('nameFil') ?? commodityId,
        m.get('name') ?? marketId,
        board.medianPrice,
        unitWord,
      );
      await notifier
        .sendToUser(a.userId, {
          ...text,
          data: { type: 'alert', alertId: a.id, commodityId, marketId },
        })
        .catch((e) => console.warn('alert push failed', (e as Error).message));
      await db.doc(`alerts/${a.id}`).update({
        lastTriggeredAt: FieldValue.serverTimestamp(),
        lastTriggeredMedian: board.medianPrice,
      });
    }
  },
  async bumpReporterScore(uid, update) {
    const ref = db.doc(`users/${uid}`);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const next = update(snap.get('reportsScored') ?? 0, snap.get('reportsNearMedian') ?? 0);
      tx.update(ref, {
        reportsScored: next.scored,
        reportsNearMedian: next.near,
        reporterScore: next.score,
      });
    });
  },
  audit: writeAudit,
};

/** Any signed-in user submits a price report; the source tier comes from the role claim. */
export const submitPriceReport = onCall((req) =>
  submitPriceReportHandler(caller(req.auth), req.data, priceStore),
);

/** Admin-only: import official DA / DAR / NVAT prices. */
export const importOfficialPrices = onCall({ timeoutSeconds: 120 }, (req) =>
  importOfficialPricesHandler(caller(req.auth), req.data, priceStore),
);

/** Recomputes median, confidence and trend for the report's commodity + market. */
export const onPriceReportCreated = onDocumentCreated('price_reports/{id}', async (event) => {
  const d = event.data?.data();
  if (!d) return;
  await onReportCreated(
    {
      commodityId: d.commodityId,
      marketId: d.marketId,
      price: d.price,
      source: d.source,
      reporterId: d.reporterId,
      batchId: d.batchId,
    },
    priceStore,
  );
});

/** Hourly: mark active listings past expiresAt as expired. */
export const expireListingsJob = onSchedule(
  { schedule: 'every 60 minutes', timeZone: 'Asia/Manila' },
  async () => {
    const n = await expireListings({
      now: () => Date.now(),
      async activeExpiredIds(beforeMs, limit) {
        const snap = await db
          .collection('listings')
          .where('status', '==', 'active')
          .where('expiresAt', '<', Timestamp.fromMillis(beforeMs))
          .limit(limit)
          .get();
        return snap.docs.map((d) => d.id);
      },
      async markExpired(ids) {
        const batch = db.batch();
        ids.forEach((id) =>
          batch.update(db.doc(`listings/${id}`), {
            status: 'expired',
            updatedAt: FieldValue.serverTimestamp(),
          }),
        );
        await batch.commit();
      },
    });
    if (n) console.log(`Expired ${n} listing(s).`);
  },
);

/** FCM sender. In the emulator FCM is not available, so messages are only logged. */
const notifier: Notifier = {
  async sendToUser(uid: string, msg: PushMessage) {
    const tokens: string[] = (await db.doc(`users/${uid}`).get()).get('fcmTokens') ?? [];
    if (process.env.FUNCTIONS_EMULATOR === 'true') {
      console.log(`[push:emulator] to ${uid} (${tokens.length} token(s)): ${msg.title}`);
      return;
    }
    if (tokens.length === 0) return;
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: msg.title, body: msg.body },
      data: msg.data,
      android: { priority: 'high', notification: { channelId: 'timbang_default' } },
    });
    // Drop tokens FCM says are dead.
    const dead = res.responses
      .map((r, i) =>
        !r.success && /registration-token-not-registered|invalid-argument/.test(r.error?.code ?? '')
          ? tokens[i]
          : null,
      )
      .filter((t): t is string => t !== null);
    if (dead.length) {
      await db.doc(`users/${uid}`).update({ fcmTokens: FieldValue.arrayRemove(...dead) });
    }
  },
};

/** Buyer asks about a listing; the farmer gets a push notification. */
export const sendInquiry = onCall((req) =>
  sendInquiryHandler(
    req.auth ? { uid: req.auth.uid } : undefined,
    req.data,
    {
      now: () => Date.now(),
      async getUser(uid) {
        const d = (await db.doc(`users/${uid}`).get()).data();
        return d
          ? { name: String(d.name), phone: String(d.phone), status: String(d.status ?? 'active') }
          : null;
      },
      async getListing(id) {
        const d = (await db.doc(`listings/${id}`).get()).data();
        return d
          ? {
              farmerId: d.farmerId,
              commodityId: d.commodityId,
              status: d.status,
              expiresAt: (d.expiresAt as Timestamp).toMillis(),
            }
          : null;
      },
      async getCommodityName(id) {
        return ((await db.doc(`commodities/${id}`).get()).get('nameFil') as string) ?? null;
      },
      async inquiriesByBuyerSince(uid, sinceMs) {
        const snap = await db
          .collection('inquiries')
          .where('buyerId', '==', uid)
          .where('createdAt', '>', Timestamp.fromMillis(sinceMs))
          .get();
        return snap.docs.map((d) => ({
          listingId: d.get('listingId'),
          createdAt: (d.get('createdAt') as Timestamp).toMillis(),
        }));
      },
      async addInquiry(i) {
        const ref = await db
          .collection('inquiries')
          .add({ ...i, createdAt: Timestamp.fromMillis(i.createdAt) });
        return ref.id;
      },
    },
    notifier,
  ),
);
