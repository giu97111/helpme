import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
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
          content: Text(e.message ?? e.code),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.red,
                    size: 48,
                  ),
                ),
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
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _checkBusy ? null : _reloadUser,
                    child: _checkBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(S.tr('verifyEmailCheck')),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: (_resendBusy || _cooldown > 0) ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
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
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: (_checkBusy || _resendBusy)
                      ? null
                      : () => FirebaseAuth.instance.signOut(),
                  child: Text(
                    S.tr('verifyEmailSignOut'),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
