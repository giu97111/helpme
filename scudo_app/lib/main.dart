import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/logged_in_shell.dart';
import 'screens/responder_map_screen.dart';
import 'services/notification_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void _openEmergencyFromMessage(RemoteMessage? message) {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null || !u.emailVerified) return;
  final id = message?.data['emergencyId'] as String?;
  if (id == null || id.isEmpty) return;
  navigatorKey.currentState?.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ResponderMapScreen(emergencyId: id),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[Scudo] FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) debugPrint(details.stack.toString());
  };

  Object? firebaseError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[Scudo] Firebase inizializzato');
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
      } catch (e) {
        debugPrint('[Scudo] App Check: $e');
      }
    }
  } catch (e, st) {
    firebaseError = e;
    debugPrint('[Scudo] ERRORE Firebase.initializeApp: $e\n$st');
  }

  if (firebaseError != null) {
    runApp(FirebaseInitErrorApp(message: firebaseError.toString()));
    return;
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ScudoApp());
}

class FirebaseInitErrorApp extends StatelessWidget {
  const FirebaseInitErrorApp({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradientBg),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline,
                        color: AppColors.red, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(S.tr('firebaseError'),
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Text(message,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 14)),
                  const SizedBox(height: 24),
                  Text(S.tr('checkConfig'),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScudoApp extends StatefulWidget {
  const ScudoApp({super.key});
  @override
  State<ScudoApp> createState() => _ScudoAppState();
}

class _ScudoAppState extends State<ScudoApp> {
  StreamSubscription<User?>? _authForInitial;
  RemoteMessage? _initialMessage;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_bootstrapNotifications);
  }

  Future<void> _bootstrapNotifications() async {
    debugPrint('[Scudo] avvio servizi notifiche (non blocca UI)...');
    try {
      await NotificationService.init();
      NotificationService.onForegroundMessage((_) {});
      NotificationService.onMessageOpenedApp(_openEmergencyFromMessage);

      final initial = await NotificationService.getInitialMessage();
      final token = await NotificationService.getTokenIfAvailable();
      debugPrint(
          '[Scudo] FCM token: ${token != null ? "presente" : "assente"}');

      final u = FirebaseAuth.instance.currentUser;
      if (u != null && token != null) {
        try {
          await UserService.updateFcmToken(u.uid, token);
        } catch (e) {
          debugPrint('[Scudo] updateFcmToken: $e');
        }
      }

      if (!mounted) return;
      setState(() => _initialMessage = initial);
      _scheduleInitialEmergencyMap();
    } catch (e, st) {
      debugPrint('[Scudo] ERRORE notifiche: $e');
      debugPrint('[Scudo] stack: $st');
    }

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      try {
        final t = await NotificationService.getTokenIfAvailable();
        if (t != null) await UserService.syncProfile(user, fcmToken: t);
      } catch (e) {
        debugPrint('[Scudo] syncProfile auth: $e');
      }
    });
  }

  void _scheduleInitialEmergencyMap() {
    final msg = _initialMessage;
    if (msg == null) return;
    final id = msg.data['emergencyId'] as String?;
    if (id == null || id.isEmpty) return;

    void open() {
      final cu = FirebaseAuth.instance.currentUser;
      if (cu == null || !cu.emailVerified) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        navigatorKey.currentState?.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ResponderMapScreen(emergencyId: id),
          ),
        );
      });
    }

    if (FirebaseAuth.instance.currentUser != null) {
      open();
    } else {
      _authForInitial =
          FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          open();
          _authForInitial?.cancel();
          _authForInitial = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _authForInitial?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: S.locale,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Scudo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          locale: currentLocale,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Container(
                    decoration:
                        const BoxDecoration(gradient: AppColors.gradientBg),
                    child: const Center(
                      child: _LoadingLogo(),
                    ),
                  ),
                );
              }
              final user = snap.data;
              if (user == null) return const AuthScreen();
              if (!user.emailVerified) {
                return const EmailVerificationScreen();
              }
              return const LoggedInShell();
            },
          ),
        );
      },
    );
  }
}

class _LoadingLogo extends StatelessWidget {
  const _LoadingLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 88, showShadow: true),
        const SizedBox(height: 24),
        Text(
          'SCUDO',
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.9),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }
}
