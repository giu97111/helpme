import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'services/account_deletion_guard.dart';
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

/// Se l’utente è stato rimosso da Firebase Auth (console o altro client), la
/// sessione locale può restare in cache: [User.reload] fallisce → logout pulito.
Future<void> _validateStoredAuthSession() async {
  await FirebaseAuth.instance.authStateChanges().first;
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return;
  try {
    await u.reload();
  } on FirebaseAuthException catch (e) {
    const fatal = <String>{
      'user-not-found',
      'invalid-user-token',
      'user-disabled',
    };
    if (fatal.contains(e.code)) {
      debugPrint(
        '[Scudo] sessione Auth non più valida (${e.code}) → signOut',
      );
      await FirebaseAuth.instance.signOut();
    }
  } catch (e) {
    debugPrint('[Scudo] Auth reload: $e');
  }
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
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Scudo] Firebase inizializzato');
    // In debug/profile l'SDK iOS può comunque chiamare exchangeDeviceCheckToken se si
    // attiva App Check; con l'API "Firebase App Check API" disabilitata in GCP si
    // ottiene 403, rate limit ("Too many attempts") e Firestore/Auth si bloccano.
    // In release usare Play Integrity / App Attest e abilitare l'API in GCP.
    if (!kIsWeb && kReleaseMode) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      } catch (e) {
        debugPrint('[Scudo] App Check: $e');
      }
    } else if (!kIsWeb) {
      debugPrint(
        '[Scudo] App Check: omesso in build non-release (debug/profile)',
      );
    }
  } catch (e, st) {
    firebaseError = e;
    debugPrint('[Scudo] ERRORE Firebase.initializeApp: $e\n$st');
  }

  if (firebaseError != null) {
    runApp(FirebaseInitErrorApp(message: firebaseError.toString()));
    return;
  }

  await _validateStoredAuthSession();

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
                    child: const Icon(
                      Icons.error_outline,
                      color: AppColors.red,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    S.tr('firebaseError'),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    S.tr('checkConfig'),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
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
  StreamSubscription<User?>? _authClearBadgeSub;
  StreamSubscription<User?>? _userChangesForFcm;
  StreamSubscription<String>? _fcmTokenRefreshSub;
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
      final token = await NotificationService.getTokenIfAvailableWithRetry();
      debugPrint(
        '[Scudo] FCM token: ${token != null ? "presente" : "assente"}',
      );

      final u = FirebaseAuth.instance.currentUser;
      if (u != null && u.emailVerified && token != null) {
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

    _authClearBadgeSub?.cancel();
    _authClearBadgeSub =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        unawaited(NotificationService.clearLauncherBadge());
      }
    });

    // authStateChanges NON emette quando passi a email verificata (stesso utente loggato):
    // senza userChanges() il token FCM non veniva mai salvato dopo la verifica mail.
    _userChangesForFcm?.cancel();
    _userChangesForFcm =
        FirebaseAuth.instance.userChanges().listen((user) async {
      if (AccountDeletionGuard.inProgress) return;
      if (user == null || !user.emailVerified) return;
      try {
        final t = await NotificationService.getTokenIfAvailableWithRetry(
          maxAttempts: 4,
          step: const Duration(milliseconds: 350),
        );
        if (t != null) await UserService.syncProfile(user, fcmToken: t);
      } catch (e) {
        debugPrint('[Scudo] syncProfile userChanges FCM: $e');
      }
    });

    _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (AccountDeletionGuard.inProgress) return;
      final cu = FirebaseAuth.instance.currentUser;
      if (cu == null || !cu.emailVerified) return;
      try {
        await UserService.updateFcmToken(cu.uid, newToken);
      } catch (e) {
        debugPrint('[Scudo] onTokenRefresh: $e');
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
      _authForInitial = FirebaseAuth.instance.authStateChanges().listen((user) {
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
    _authClearBadgeSub?.cancel();
    _userChangesForFcm?.cancel();
    _fcmTokenRefreshSub?.cancel();
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
          // authStateChanges emette subito null dopo signOut; userChanges() può ritardare
          // e lasciare la schermata di caricamento → dopo elimina account non si vede il login.
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingShell();
              }
              final user = snap.data;
              if (user == null) return const AuthScreen();
              return const _SignedInRouter();
            },
          ),
        );
      },
    );
  }
}

/// Dopo login: verifica email e profilo Firestore (userChanges aggiorna senza nuovo sign-in).
class _SignedInRouter extends StatelessWidget {
  const _SignedInRouter();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        final cu = FirebaseAuth.instance.currentUser;
        if (cu == null) return const AuthScreen();
        final u = snap.data ?? cu;
        if (u.uid != cu.uid) return const AuthScreen();
        if (!u.emailVerified) {
          return const EmailVerificationScreen();
        }
        return _FirestoreProfileGate(uid: u.uid);
      },
    );
  }
}

/// Sessione valida solo se esiste il profilo in `users/{uid}` (oltre ad Auth + email verificata).
class _FirestoreProfileGate extends StatelessWidget {
  const _FirestoreProfileGate({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    // Dopo delete account o sign-out nativo, `userChanges()` può ritardare: senza questo
    // restiamo su _LoadingShell (schermo grigio) finché lo stream padre non emette null.
    final cu = FirebaseAuth.instance.currentUser;
    if (cu == null || cu.uid != uid) {
      return const AuthScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: UserService.userDocStream(uid),
      builder: (context, docSnap) {
        if (docSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingShell();
        }
        if (docSnap.hasError) {
          debugPrint('[Scudo] users/$uid: ${docSnap.error}');
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await FirebaseAuth.instance.signOut();
          });
          return const _LoadingShell();
        }
        final doc = docSnap.data;
        if (doc == null || !doc.exists) {
          final fresh = FirebaseAuth.instance.currentUser;
          if (fresh != null &&
              fresh.uid == uid &&
              fresh.emailVerified) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await UserService.syncProfileIfVerified(fresh);
              } catch (e) {
                debugPrint('[Scudo] syncProfileIfVerified gate: $e');
              }
            });
            return const _LoadingShell();
          }
          debugPrint('[Scudo] nessun documento users/$uid → logout');
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await FirebaseAuth.instance.signOut();
          });
          return const _LoadingShell();
        }
        return const LoggedInShell();
      },
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: const Center(child: _LoadingLogo()),
      ),
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
