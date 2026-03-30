/**
 * Scudo — notifiche push quando viene creata un'emergenza.
 * Deploy: firebase deploy --only functions
 *
 * Raggio default: 2000 m (puoi abbassare a 500 in produzione).
 *
 * Test con due telefoni lontani geograficamente:
 *   firebase functions:config:set scudo.broadcast_all="true"
 *   firebase deploy --only functions
 * Disattiva:
 *   firebase functions:config:unset scudo
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const https = require('https');
const path = require('path');
const fs = require('fs');

/**
 * Ordine di priorità per le credenziali:
 *   1. File service-account-key.json nella stessa cartella (deployato con la funzione)
 *   2. Variabile d'ambiente FIREBASE_SERVICE_ACCOUNT_JSON
 *   3. Application Default Credentials (metadata server su GCP)
 */
function initFirebaseAdmin() {
  if (admin.apps.length) return;

  const keyFromFile = loadServiceAccountKeyFile();
  if (keyFromFile) {
    console.log('initFirebaseAdmin: credenziale da service-account-key.json');
    admin.initializeApp({credential: admin.credential.cert(keyFromFile)});
    return;
  }

  const keyFromEnv = parseServiceAccountJsonFromEnv();
  if (keyFromEnv) {
    console.log('initFirebaseAdmin: credenziale da FIREBASE_SERVICE_ACCOUNT_JSON');
    admin.initializeApp({credential: admin.credential.cert(keyFromEnv)});
    return;
  }

  if (shouldStripGoogleApplicationCredentials()) {
    const had = !!process.env.GOOGLE_APPLICATION_CREDENTIALS;
    delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
    console.log(
        `initFirebaseAdmin: GCP runtime — GOOGLE_APPLICATION_CREDENTIALS ${had ? 'RIMOSSA' : 'assente'}`,
    );
  }

  admin.initializeApp({credential: admin.credential.applicationDefault()});
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

/** True in produzione su GCP (1ª gen, 2ª gen, Cloud Run), false in emulatore locale. */
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
        victimUidRaw != null && String(victimUidRaw).trim() !== ''
          ? String(victimUidRaw).trim()
          : null;
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

      const cfg = functions.config();
      const broadcastAll =
        cfg.scudo && String(cfg.scudo.broadcast_all).toLowerCase() === 'true';

      if (broadcastAll) {
        console.log(
            'MODALITÀ TEST: broadcast_all=true → invio a tutti con FCM (ignora distanza)',
        );
      } else {
        console.log(
            `Raggio notifiche: ${RADIUS_METERS}m (nessun match se l'altro utente è più lontano)`,
        );
      }

      const db = admin.firestore();
      const usersSnap = await db.collection('users').get();

      let totalOthers = 0;
      let withToken = 0;
      let withCoords = 0;
      let minDist = Infinity;

      /** @type {string[]} */
      const tokens = [];

      usersSnap.forEach((doc) => {
        if (doc.id === victimUidStr) return;
        totalOthers++;

        const u = doc.data();
        const token = u.fcmToken;
        if (token && typeof token === 'string') withToken++;

        const lat = u.lastLat;
        const lng = u.lastLng;
        const hasCoords = typeof lat === 'number' && typeof lng === 'number';
        if (hasCoords) withCoords++;

        if (!token || typeof token !== 'string') return;

        if (broadcastAll) {
          tokens.push(token);
          return;
        }

        if (!hasCoords) return;

        const dist = haversineMeters(victimLat, victimLng, lat, lng);
        if (dist < minDist) minDist = dist;
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

      console.log(
          `DEBUG utenti: altri=${totalOthers} con_fcmToken=${withToken} ` +
      `con_lastLat_lng=${withCoords} distanza_min_m=${minDist === Infinity ? 'n/a' : Math.round(minDist)}`,
      );

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

      console.log(
          `DEBUG: token length=${accessToken ? accessToken.length : 'NULL'}, ` +
          `starts=${accessToken ? accessToken.substring(0, 12) + '…' : 'N/A'}`,
      );

      const projectId = 'helpme-c8755';

      let successCount = 0;
      let failureCount = 0;

      for (let i = 0; i < uniqueTokens.length; i++) {
        const payload = JSON.stringify({
          message: {
            token: uniqueTokens[i],
            notification: {
              title: 'Richiesta di aiuto nelle vicinanze',
              body: `${displayName} potrebbe aver bisogno di te.`,
            },
            data: {
              emergencyId: String(emergencyId),
              type: 'sos',
            },
            android: {
              priority: 'high',
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
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
              res.on('data', (chunk) => { body += chunk; });
              res.on('end', () => {
                resolve({status: res.statusCode, body});
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
