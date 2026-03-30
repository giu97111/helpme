import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../branding.dart';

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

  static Uint8List? _notificationLogoBytes;

  static Future<void> _loadNotificationLogo() async {
    try {
      final data = await rootBundle.load(kAppLogoAsset);
      _notificationLogoBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint('[Scudo FCM] logo notifiche non caricato: $e');
    }
  }

  static Future<void> init() async {
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
    );
    await _loadNotificationLogo();

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    final messaging = FirebaseMessaging.instance;
    // iOS: alert false così non duplichiamo la push di sistema; mostriamo noi la notifica locale con allegato (logo).
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
      // Come su iOS: alert false così non mostra la notifica di sistema (icona launcher / Dart);
      // usiamo solo flutter_local_notifications con ic_notification + logo.
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

  /// File temporaneo per allegato immagine su iOS (UNNotificationAttachment).
  static Future<String?> _logoTempPathForIos() async {
    final bytes = _notificationLogoBytes;
    if (bytes == null) return null;
    final f = File('${Directory.systemTemp.path}/scudo_push_logo.jpg');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
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

      final id = eid != null && eid.isNotEmpty
          ? eid.hashCode & 0x7fffffff
          : message.messageId?.hashCode ?? message.hashCode;

      if (Platform.isAndroid) {
        await _local.show(
          id,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: 'ic_notification',
              color: const Color(0xFFFF3B30),
              largeIcon: _notificationLogoBytes != null
                  ? ByteArrayAndroidBitmap(_notificationLogoBytes!)
                  : null,
            ),
          ),
          payload: message.data['emergencyId'],
        );
      } else if (Platform.isIOS) {
        final logoPath = await _logoTempPathForIos();
        await _local.show(
          id,
          n.title,
          n.body,
          NotificationDetails(
            iOS: DarwinNotificationDetails(
              // Un solo banner: evita banner + lista + alert duplicati in centro notifiche.
              presentAlert: false,
              presentBanner: true,
              presentList: false,
              presentSound: true,
              presentBadge: true,
              attachments: logoPath != null
                  ? <DarwinNotificationAttachment>[
                      DarwinNotificationAttachment(logoPath),
                    ]
                  : null,
            ),
          ),
          payload: message.data['emergencyId'],
        );
      }

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
}
