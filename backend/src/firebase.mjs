import admin from 'firebase-admin';
import { readFileSync } from 'node:fs';

const SA_PATH = process.env.FIREBASE_SA_PATH
  || '/opt/bre4ch/firebase-service-account.json';

let firebaseApp = null;

try {
  const serviceAccount = JSON.parse(readFileSync(SA_PATH, 'utf-8'));
  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('[FCM] Firebase Admin initialized');
} catch (err) {
  console.warn(`[FCM] Firebase not initialized: ${err.message}`);
}

export const messaging = firebaseApp ? admin.messaging() : null;
export default firebaseApp;
