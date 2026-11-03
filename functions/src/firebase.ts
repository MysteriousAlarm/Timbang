import { initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

if (getApps().length === 0) initializeApp();

export const auth = getAuth();
export const db = getFirestore();

export async function writeAudit(entry: {
  actorId: string;
  action: string;
  targetPath: string;
  detail: string;
}): Promise<void> {
  await db.collection('audit_logs').add({ ...entry, timestamp: FieldValue.serverTimestamp() });
}
