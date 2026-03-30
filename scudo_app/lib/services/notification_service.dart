import 'dart:async';
import 'dart:io';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _local = FlutterLocalNotificationsPlugin();

const _androidChannel = AndroidNotificationChannel(
  'scudo_sos',
  'Allarmi SOS',
  description: 'Notifiche di emergenza da utenti vicini',
  importance: Importance.max,
);

class NotificationService {
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;

  /// Evita listener duplicati (hot restart / doppio init) → notifiche triple o comportamenti strani.
  static final Map<String, DateTime> _dedupeForegroundByEmergency = {};

  /// Stesso messaggio FCM su iOS può essere gestito più volte (Firebase + delegate).
  static String? _lastForegroundMessageId;
  static DateTime? _lastForegroundMessageIdAt;

  static Future<void> init({
    void Function(String? emergencyIdPayload)? onLocalNotificationTap,
  }) async {
    await _local.initialize(
      InitializationSettings(
        // Solo il nome risorsa (senza @drawable/): così getIdentifier() su Android trova il drawable.
        android: const AndroidInitializationSettings('ic_notification'),
        // iOS: NON mostrare automaticamente la push remota in foreground (icona default).
        // Firebase inoltra willPresentNotification a questo plugin: se i default sono true,
        // si somma alla notifica locale che creiamo noi in onMessage → 2–3 volte la stessa SOS.
        iOS: Platform.isIOS
            ? const DarwinInitializationSettings(
                defaultPresentAlert: false,
                defaultPresentBanner: false,
                defaultPresentList: false,
                defaultPresentSound: true,
                defaultPresentBadge: true,
              )
            : const DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onLocalNotificationTap?.call(response.payload);
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: true,
      );
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }
    if (Platform.isAndroid) {
      await FirebaseMessaging.instance.requestPermission();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: true,
      );
    }
  }

  static Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  /// Su iOS senza APNS (simulatore o capability mancante) [getToken] lancia. Non propagare l’errore.
  static Future<String?> getTokenIfAvailable() async {
    try {
      if (Platform.isIOS) {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns == null) {
          return null;
        }
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      // es. apns-token-not-set
      debugPrint('[Scudo FCM] token non disponibile: $e');
      return null;
    }
  }

  /// Dopo login/registrazione l’APNS può arrivare con ritardo: ritenta prima di arrendersi.
  static Future<String?> getTokenIfAvailableWithRetry({
    int maxAttempts = 6,
    Duration step = const Duration(milliseconds: 400),
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final t = await getTokenIfAvailable();
      if (t != null) return t;
      await Future<void>.delayed(step * (i + 1));
    }
    return null;
  }

  static void onForegroundMessage(void Function(RemoteMessage) handler) {
    _onMessageSubscription?.cancel();
    _onMessageSubscription = FirebaseMessaging.onMessage.listen((message) async {
      final n = message.notification;
      if (n == null) {
        handler(message);
        return;
      }

      final mid = message.messageId;
      if (mid != null && mid.isNotEmpty) {
        final now = DateTime.now();
        if (mid == _lastForegroundMessageId &&
            _lastForegroundMessageIdAt != null &&
            now.difference(_lastForegroundMessageIdAt!) <
                const Duration(seconds: 8)) {
          handler(message);
          return;
        }
        _lastForegroundMessageId = mid;
        _lastForegroundMessageIdAt = now;
      }

      final eid = message.data['emergencyId'] as String?;
      if (eid != null && eid.isNotEmpty) {
        final prev = _dedupeForegroundByEmergency[eid];
        final now = DateTime.now();
        if (prev != null && now.difference(prev) < const Duration(seconds: 6)) {
          handler(message);
          return;
        }
        _dedupeForegroundByEmergency[eid] = now;
        if (_dedupeForegroundByEmergency.length > 32) {
          _dedupeForegroundByEmergency.removeWhere(
            (_, t) => now.difference(t) > const Duration(minutes: 2),
          );
        }
      }

      // In foreground: niente banner / schermata allarme; il badge è aggiornato da
      // [LoggedInShell] in base alle emergenze attive vicine.

      handler(message);
    });
  }

  static void onMessageOpenedApp(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  static Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();

  /// Azzera il numero sull’icona app (iOS / launcher Android che lo supportano).
  static Future<void> clearLauncherBadge() async {
    if (kIsWeb) return;
    try {
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(0);
      }
    } catch (e) {
      debugPrint('[Scudo FCM] clearLauncherBadge: $e');
    }
  }

  /// Imposta il numero sull’icona (es. emergenze vicine attive).
  static Future<void> updateLauncherBadge(int count) async {
    if (kIsWeb) return;
    try {
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(count < 0 ? 0 : count);
      }
    } catch (e) {
      debugPrint('[Scudo FCM] updateLauncherBadge: $e');
    }
  }
}
