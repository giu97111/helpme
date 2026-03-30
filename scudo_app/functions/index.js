/**
 * Scudo — notifiche push quando viene creata un'emergenza.
 * Deploy: firebase deploy --only functions
 *
 * Raggio default: 2000 m (puoi abbassare a 500 in produzione).
 *
 * Test con due telefoni lontani geograficamente: in functions/.env imposta
 *   SCUDO_BROADCAST_ALL=true
 * poi dalla cartella scudo_app (dove c’è firebase.json):
 *   firebase deploy --only functions
 *
 * Immagine grande nelle push: il server FCM accetta solo un URL HTTPS (non file
 * nell’app). Opzionale: SCUDO_NOTIFICATION_IMAGE_URL in .env (es. Firebase Storage).
 * L’app usa sempre `assets/logo.jpg` per le notifiche locali in foreground.
 *
 * Deploy: sempre da scudo_app, altrimenti "No targets match --only functions".
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const {defineBoolean, defineString} = require('firebase-functions/params');

/** Modalità test: invia FCM a tutti (ignora distanza). */
const scudoBroadcastAll = defineBoolean('SCUDO_BROADCAST_ALL', {
  default: false,
});

/** URL HTTPS pubblico del logo per FCM (opzionale). */
const scudoNotificationImageUrl = defineString('SCUDO_NOTIFICATION_IMAGE_URL', {
  default: '',
});
const https = require('https');
const path = require('path');
const fs = require('fs');

/**
 * Bucket Storage del progetto (es. helpme-c8755.firebasestorage.app).
 * Senza questo, admin.storage().bucket() in Cloud Functions fallisce con
 * "Bucket name not specified or invalid" per i bucket *.firebasestorage.app.
 * @return {string}
 */
function resolveStorageBucket() {
  try {
    if (process.env.FIREBASE_CONFIG) {
      const cfg = JSON.parse(process.env.FIREBASE_CONFIG);
      if (cfg.storageBucket && typeof cfg.storageBucket === 'string') {
        return cfg.storageBucket;
      }
    }
  } catch (e) {
    console.warn(`resolveStorageBucket: ${e.message || e}`);
  }
  const pid =
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    'helpme-c8755';
  return `${pid}.firebasestorage.app`;
}

/**
 * Ordine di priorità per le credenziali:
 *   1. File service-account-key.json nella stessa cartella (deployato con la funzione)
 *   2. Variabile d'ambiente FIREBASE_SERVICE_ACCOUNT_JSON
 *   3. Application Default Credentials (metadata server su GCP)
 */
function initFirebaseAdmin() {
  if (admin.apps.length) return;

  const storageBucket = resolveStorageBucket();
  const keyFromFile = loadServiceAccountKeyFile();
  if (keyFromFile) {
    console.log('initFirebaseAdmin: credenziale da service-account-key.json');
    admin.initializeApp({
      credential: admin.credential.cert(keyFromFile),
      storageBucket,
    });
    return;
  }

  const keyFromEnv = parseServiceAccountJsonFromEnv();
  if (keyFromEnv) {
    console.log('initFirebaseAdmin: credenziale da FIREBASE_SERVICE_ACCOUNT_JSON');
    admin.initializeApp({
      credential: admin.credential.cert(keyFromEnv),
      storageBucket,
    });
    return;
  }

  if (shouldStripGoogleApplicationCredentials()) {
    const had = !!process.env.GOOGLE_APPLICATION_CREDENTIALS;
    delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
    console.log(
        `initFirebaseAdmin: GCP runtime — GOOGLE_APPLICATION_CREDENTIALS ${had ? 'RIMOSSA' : 'assente'}`,
    );
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    storageBucket,
  });
  console.log('initFirebaseAdmin: inizializzato con applicationDefault()');
}

/** @return {Record<string, unknown>|null} */
function loadServiceAccountKeyFile() {
  const filePath = path.join(__dirname, 'service-account-key.json');
  try {
    if (!fs.existsSync(filePath)) return null;
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    console.warn('service-account-key.json trovato ma non valido');
    return null;
  }
}

/**
 * True in produzione su GCP (1ª gen, 2ª gen, Cloud Run), false in emulatore locale.
 * @return {boolean}
 */
function shouldStripGoogleApplicationCredentials() {
  if (process.env.FUNCTIONS_EMULATOR === 'true') return false;
  return Boolean(
      process.env.FUNCTION_TARGET ||
      process.env.K_SERVICE ||
      process.env.FUNCTION_NAME,
  );
}

/** @return {Record<string, unknown>|null} */
function parseServiceAccountJsonFromEnv() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw || typeof raw !== 'string') return null;
  try {
    return JSON.parse(raw);
  } catch {
    try {
      return JSON.parse(Buffer.from(raw.trim(), 'base64').toString('utf8'));
    } catch {
      throw new Error(
          'FIREBASE_SERVICE_ACCOUNT_JSON non è JSON valido né base64 di un JSON',
      );
    }
  }
}

initFirebaseAdmin();

/**
 * Project ID per FCM HTTP v1 (runtime GCP o fallback).
 * @return {string}
 */
function getProjectId() {
  return (
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    admin.app().options.projectId ||
    'helpme-c8755'
  );
}

/** Conteggio utenti per la home (solo backend; le regole Firestore bloccano il count client). */
exports.getPublicUserCount = functions
    .region('europe-west1')
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Autenticazione richiesta.',
        );
      }
      const db = admin.firestore();
      const snap = await db.collection('users').count().get();
      const count = snap.data().count;
      return {count};
    });

/**
 * Elimina account: prima Auth così il client perde subito il token e non può
 * riscrivere `users/{uid}` (merge) mentre la funzione gira. Poi Firestore e Storage.
 * Il trigger cleanupUserOnAuthDelete fa anche lui pulizia se qualcosa resta.
 */
exports.deleteMyAccount = functions
    .region('europe-west1')
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Autenticazione richiesta.',
        );
      }
      const uid = context.auth.uid;
      const db = admin.firestore();
      try {
        await admin.auth().deleteUser(uid);
      } catch (e) {
        console.error(`deleteMyAccount: auth.deleteUser ${e.message || e}`);
        throw new functions.https.HttpsError(
            'internal',
            'Impossibile eliminare l\'account.',
        );
      }
      try {
        await db.collection('users').doc(uid).delete();
      } catch (e) {
        console.warn(`deleteMyAccount: users/${uid} ${e.message || e}`);
      }
      try {
        const bucket = admin.storage().bucket(resolveStorageBucket());
        await bucket.file(`profile_photos/${uid}/profile.jpg`).delete({
          ignoreNotFound: true,
        });
      } catch (e) {
        console.warn(`deleteMyAccount: storage ${e.message || e}`);
      }
      return {ok: true};
    });

/**
 * Se un utente viene eliminato dalla console (solo Auth) o da un altro client,
 * rimuove anche `users/{uid}` e la foto in Storage — evita documenti orfani.
 */
exports.cleanupUserOnAuthDelete = functions.auth.user().onDelete(
    async (user) => {
      const uid = user.uid;
      const db = admin.firestore();
      try {
        await db.collection('users').doc(uid).delete();
      } catch (e) {
        console.warn(`cleanupUserOnAuthDelete: users/${uid} ${e.message || e}`);
      }
      try {
        const bucket = admin.storage().bucket(resolveStorageBucket());
        await bucket.file(`profile_photos/${uid}/profile.jpg`).delete({
          ignoreNotFound: true,
        });
      } catch (e) {
        console.warn(`cleanupUserOnAuthDelete: storage ${e.message || e}`);
      }
    });

/** Metri — abbassa in produzione se vuoi solo vicini stretti */
const RADIUS_METERS = 2000;

/**
 * Distanza sulla superficie terrestre (metri).
 * @param {number} lat1
 * @param {number} lon1
 * @param {number} lat2
 * @param {number} lon2
 * @return {number}
 */
function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

exports.notifyNearbyOnEmergency = functions
    .region('europe-west1')
    .runWith({
      memory: '512MB',
      timeoutSeconds: 120,
    })
    .firestore.document('emergencies/{emergencyId}')
    .onCreate(async (snap, context) => {
      const emergencyId = context.params.emergencyId;
      console.log(`INVOKED notifyNearbyOnEmergency emergencyId=${emergencyId}`);

      const data = snap.data();

      if (!data || data.status !== 'active') {
        console.log('notifyNearbyOnEmergency: status non active, skip');
        return;
      }

      const victimUidRaw = data.userId;
      const victimUidStr =
        victimUidRaw != null && String(victimUidRaw).trim() !== '' ?
          String(victimUidRaw).trim() :
          null;
      if (!victimUidStr) {
        console.warn('notifyNearbyOnEmergency: userId mancante, skip FCM');
        return;
      }

      const victimLat = data.lat;
      const victimLng = data.lng;
      const displayName = data.displayName || 'Un utente';

      if (typeof victimLat !== 'number' || typeof victimLng !== 'number') {
        console.warn('notifyNearbyOnEmergency: lat/lng mancanti');
        return;
      }

      const broadcastAll = scudoBroadcastAll.value();
      const notificationImageUrl = scudoNotificationImageUrl.value().trim();
      if (notificationImageUrl) {
        console.log(
            `notifyNearbyOnEmergency: immagine notifica (FCM image)=${notificationImageUrl.substring(0, 48)}…`,
        );
      } else {
        console.log(
            'notifyNearbyOnEmergency: nessun URL immagine (opzionale) — ' +
          'solo icona nelle push; in app il logo resta assets/logo.jpg in foreground.',
        );
      }

      if (broadcastAll) {
        console.warn(
            'ATTENZIONE: SCUDO_BROADCAST_ALL attivo → FCM a TUTTI gli utenti (ignora distanza). ' +
          'Disattiva in produzione.',
        );
      } else {
        console.log(
            `Raggio notifiche: ${RADIUS_METERS}m (nessun match se l'altro utente è più lontano)`,
        );
      }

      const db = admin.firestore();
      const usersSnap = await db.collection('users').get();

      /** @type {string[]} */
      const tokens = [];

      usersSnap.forEach((doc) => {
        if (doc.id === victimUidStr) return;

        const u = doc.data();
        const token = u.fcmToken;

        const lat = u.lastLat;
        const lng = u.lastLng;
        const hasCoords = typeof lat === 'number' && typeof lng === 'number';

        if (!token || typeof token !== 'string') return;

        if (broadcastAll) {
          tokens.push(token);
          return;
        }

        if (!hasCoords) return;

        const dist = haversineMeters(victimLat, victimLng, lat, lng);
        if (dist <= RADIUS_METERS) {
          tokens.push(token);
        }
      });

      let victimFcmToken = null;
      const victimUserSnap = await db.collection('users').doc(victimUidStr).get();
      if (victimUserSnap.exists) {
        const vf = victimUserSnap.data();
        if (vf && typeof vf.fcmToken === 'string' && vf.fcmToken.length > 0) {
          victimFcmToken = vf.fcmToken;
        }
      }

      const uniqueTokens = [...new Set(tokens)].filter(
          (t) => !victimFcmToken || t !== victimFcmToken,
      );

      console.log(
          `notifyNearbyOnEmergency: emergencyId=${emergencyId} destinatari FCM: ${uniqueTokens.length}`,
      );

      if (uniqueTokens.length === 0) {
        console.warn(
            'NESSUN destinatario: servono altri utenti in users con fcmToken e lastLat/lastLng ' +
        `(entro ${RADIUS_METERS}m), oppure attiva broadcast_all per test.`,
        );
        return;
      }

      const {GoogleAuth} = require('google-auth-library');
      const saKey = loadServiceAccountKeyFile();
      const auth = new GoogleAuth({
        credentials: saKey || undefined,
        scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
      });
      const client = await auth.getClient();
      const {token: accessToken} = await client.getAccessToken();
      if (!accessToken) {
        console.error('notifyNearbyOnEmergency: access token OAuth assente');
        return;
      }

      const projectId = getProjectId();

      let successCount = 0;
      let failureCount = 0;

      /** @type {{channel_id: string, icon: string, color: string, image?: string}} */
      const androidNotification = {
        channel_id: 'scudo_sos',
        icon: 'ic_notification',
        color: '#FF3B30',
      };
      if (notificationImageUrl) {
        androidNotification.image = notificationImageUrl;
      }

      // iOS: icona notifica = AppIcon (non c’è drawable come Android). Subtitle “Scudo”
      // come brand (simile a label rossa + icona su Android).
      /** @type {Record<string, unknown>} */
      const apns = {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: 'Richiesta di aiuto nelle vicinanze',
              subtitle: 'Scudo',
              body: `${displayName} potrebbe aver bisogno di te.`,
            },
          },
        },
      };
      if (notificationImageUrl) {
        apns.payload.aps['mutable-content'] = 1;
        apns.fcm_options = {image: notificationImageUrl};
      }

      for (let i = 0; i < uniqueTokens.length; i++) {
        const dataFields = {
          emergencyId: String(emergencyId),
          type: 'sos',
        };
        if (notificationImageUrl) {
          dataFields.imageUrl = String(notificationImageUrl);
        }
        const payload = JSON.stringify({
          message: {
            token: uniqueTokens[i],
            notification: {
              title: 'Richiesta di aiuto nelle vicinanze',
              body: `${displayName} potrebbe aver bisogno di te.`,
              image: notificationImageUrl || undefined,
            },
            data: dataFields,
            android: {
              priority: 'high',
              notification: androidNotification,
            },
            apns,
          },
        });

        try {
          const result = await new Promise((resolve, reject) => {
            const req = https.request({
              hostname: 'fcm.googleapis.com',
              port: 443,
              path: `/v1/projects/${projectId}/messages:send`,
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              },
            }, (res) => {
              let body = '';
              res.on('data', (chunk) => {
                body += chunk;
              });
              res.on('end', () => {
                resolve({
                  status: res.statusCode,
                  body,
                });
              });
            });
            req.on('error', reject);
            req.write(payload);
            req.end();
          });

          const parsed = JSON.parse(result.body);
          if (result.status === 200) {
            successCount++;
            console.log(`FCM OK token[${i}]: ${parsed.name}`);
          } else {
            failureCount++;
            console.warn(
                `FCM FAIL token[${i}]: HTTP ${result.status} ${result.body}`,
            );
          }
        } catch (err) {
          failureCount++;
          console.warn(`FCM FAIL token[${i}]: ${err.message}`);
        }
      }

      console.log(`FCM totale: success=${successCount} failure=${failureCount}`);
    });
