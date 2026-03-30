import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _local = FlutterLocalNotificationsPlugin();

const _androidChannel = AndroidNotificationChannel(
  'scudo_sos',
  'Allarmi SOS',
  description: 'Notifiche di emergenza da utenti vicini',
  importance: Importance.max,
);

class NotificationService {
  static const _logoAssetPath = 'assets/logo.jpg';
  static Uint8List? _notificationLogoBytes;

  static Future<void> _loadNotificationLogo() async {
    try {
      final data = await rootBundle.load(_logoAssetPath);
      _notificationLogoBytes = data.buffer.asUint8List();
    } catch (e) {
      debugPrint('[Scudo FCM] logo notifiche non caricato: $e');
    }
  }

  static Future<void> init() async {
    await _local.initialize(
      const InitializationSettings(
        // Stessa icona monocromatica delle FCM in background (drawable nativo).
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(),
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
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isIOS) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }
    if (Platform.isAndroid) {
      await FirebaseMessaging.instance.requestPermission();
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

  static void onForegroundMessage(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      final android = message.notification?.android;
      if (n != null && android != null && Platform.isAndroid) {
        await _local.show(
          android.hashCode,
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
      }
      handler(message);
    });
  }

  static void onMessageOpenedApp(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  static Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
}
