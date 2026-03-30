import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/language_sheet.dart';

/// Blocca l'app finché l'email non è verificata (Firebase Auth).
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  bool _checkBusy = false;
  bool _resendBusy = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadUserSilently();
    }
  }

  Future<void> _reloadUserSilently() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      await u.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null && fresh.emailVerified) {
        final t = await NotificationService.getTokenIfAvailableWithRetry();
        await UserService.syncProfileIfVerified(fresh, fcmToken: t);
      }
    } catch (_) {}
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _reloadUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() => _checkBusy = true);
    try {
      await u.reload();
      if (!mounted) return;
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null && fresh.emailVerified) {
        final t = await NotificationService.getTokenIfAvailableWithRetry();
        await UserService.syncProfileIfVerified(fresh, fcmToken: t);
      }
      if (!mounted) return;
      if (fresh != null && !fresh.emailVerified) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(S.tr('verifyEmailNotVerifiedTitle')),
            content: Text(S.tr('verifyEmailNotVerifiedBody')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkBusy = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() => _resendBusy = true);
    try {
      await u.sendEmailVerification();
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.tr('verifyEmailSent')),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.authFirebaseError(e)),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _resendBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final email = u?.email ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => showLanguagePickerSheet(context),
                      icon: Text(
                        S.localeFlags[S.locale.value.languageCode] ?? '',
                        style: const TextStyle(fontSize: 20),
                      ),
                      label: Text(
                        S.localeLabels[S.locale.value.languageCode] ?? '',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Center(child: AppLogo(size: 96)),
                const SizedBox(height: 28),
                Text(
                  S.tr('verifyEmailTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  S.trWith('verifyEmailBody', {'email': email}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  S.tr('verifyEmailSpamHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _checkBusy ? null : _reloadUser,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: _checkBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          S.tr('verifyEmailCheck'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed:
                      (_resendBusy || _cooldown > 0) ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: _resendBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.red,
                          ),
                        )
                      : Text(
                          _cooldown > 0
                              ? S.trWith(
                                  'verifyEmailCooldown', {'n': '$_cooldown'})
                              : S.tr('verifyEmailResend'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: (_checkBusy || _resendBusy)
                      ? null
                      : () => FirebaseAuth.instance.signOut(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    S.tr('verifyEmailSignOut'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
