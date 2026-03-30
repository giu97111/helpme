import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/profile_photo_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_container.dart';
import '../widgets/language_sheet.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();
  final _picker = ImagePicker();
  bool _register = false;
  bool _loading = false;
  String? _error;
  XFile? _signupPhoto;
  Uint8List? _signupPhotoBytes;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    super.dispose();
  }

  String _friendlyAuthBackendBlob(String blob, FirebaseAuthException? e) {
    if (blob.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Identity Toolkit API not enabled. Enable it in GCP Console.';
    }
    if (blob.contains('API_KEY_INVALID') ||
        blob.contains('API key not valid')) {
      return 'Invalid or restricted API key.';
    }
    if (e != null) return '${e.message ?? "Auth error"} [${e.code}]';
    return blob;
  }

  String _friendlyFirestoreMessage(String blob) {
    if (blob.contains('does not exist') &&
        (blob.contains('database') || blob.contains('Firestore'))) {
      return 'Firestore database not created. Create it in Firebase Console.';
    }
    if (blob.contains('firestore.googleapis.com') ||
        blob.contains('Cloud Firestore API')) {
      return 'Cloud Firestore API not enabled on GCP.';
    }
    final short = blob.length > 280 ? '${blob.substring(0, 280)}…' : blob;
    return 'Firestore error.\n\n$short';
  }

  Future<void> _onSyncProfileFailed(
      Object e, StackTrace st, String mode) async {
    debugPrint('[$mode] syncProfile error: $e');
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() => _error = _friendlyFirestoreMessage(e.toString()));
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final mode = _register ? 'SIGNUP' : 'LOGIN';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        if (_name.text.trim().isEmpty) {
          setState(() => _error = S.tr('insertName'));
          return;
        }
        if (_password.text.length < 6) {
          setState(() => _error = S.tr('passwordTooShort'));
          return;
        }
        if (_password.text != _confirmPassword.text) {
          setState(() => _error = S.tr('passwordMismatch'));
          return;
        }
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
        await cred.user?.updateDisplayName(_name.text.trim());
        await cred.user?.reload();
        var u = auth.currentUser;
        if (u != null && _signupPhoto != null) {
          try {
            final url =
                await ProfilePhotoService.uploadProfilePhoto(u.uid, _signupPhoto!);
            await u.updatePhotoURL(url);
            await u.reload();
            u = auth.currentUser;
          } catch (e) {
            debugPrint('[Auth] signup photo: $e');
          }
        }
        if (u != null) {
          try {
            await UserService.syncProfile(u);
          } catch (e, st) {
            await _onSyncProfileFailed(e, st, mode);
            return;
          }
          try {
            await u.sendEmailVerification();
          } catch (e) {
            debugPrint('[Auth] sendEmailVerification: $e');
          }
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
        final u = auth.currentUser;
        if (u != null) {
          try {
            await UserService.syncProfile(u);
          } catch (e, st) {
            await _onSyncProfileFailed(e, st, mode);
            return;
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      final blob = '${e.toString()} ${e.message ?? ''}';
      setState(() => _error = _friendlyAuthBackendBlob(blob, e));
    } on PlatformException catch (e) {
      setState(() => _error = '${e.message ?? e.code} [${e.code}]');
    } catch (e) {
      setState(
          () => _error = _friendlyAuthBackendBlob(e.toString(), null));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final ctrl = TextEditingController(text: _email.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          S.tr('resetPasswordTitle'),
          style: const TextStyle(color: AppColors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.tr('resetPasswordHint'),
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: S.tr('email'),
                labelStyle: const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              final em = ctrl.text.trim();
              if (em.isEmpty) return;
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: em);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.tr('resetPasswordSent')),
                    backgroundColor: AppColors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.message ?? S.tr('resetPasswordError'),
                    ),
                    backgroundColor: AppColors.red,
                  ),
                );
              }
            },
            child: Text(S.tr('resetPasswordSend')),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _pickSignupPhoto() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _signupPhoto = x;
      _signupPhotoBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: Stack(
          children: [
            // Radial glow behind logo
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.red.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Top bar with language
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => showLanguagePickerSheet(context),
                          icon: Text(
                              S.localeFlags[S.locale.value.languageCode] ?? '',
                              style: const TextStyle(fontSize: 20)),
                          label: Text(
                            S.localeLabels[S.locale.value.languageCode] ?? '',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          const SizedBox(
                            height: 140,
                            child: Center(
                              child: AppLogo(size: 112),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SCUDO',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                    fontSize: 36, letterSpacing: 8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            S.tr('subtitleFull'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                                height: 1.5),
                          ),
                          const SizedBox(height: 36),
                          // Form card
                          GlassContainer(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _register
                                      ? S.tr('register')
                                      : S.tr('login'),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white),
                                ),
                                const SizedBox(height: 20),
                                if (_register) ...[
                                  TextField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      labelText: S.tr('yourName'),
                                      prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: AppColors.muted),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Column(
                                      children: [
                                        GestureDetector(
                                          onTap: _loading
                                              ? null
                                              : _pickSignupPhoto,
                                          child: Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.border,
                                                width: 2,
                                              ),
                                              color: AppColors.surface,
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: _signupPhotoBytes != null
                                                ? Image.memory(
                                                    _signupPhotoBytes!,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Icon(
                                                    Icons.add_a_photo_outlined,
                                                    size: 40,
                                                    color: AppColors.muted
                                                        .withValues(
                                                            alpha: 0.8),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          S.tr('addPhotoOptional'),
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                TextField(
                                  controller: _email,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    labelText: S.tr('email'),
                                    prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        color: AppColors.muted),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: S.tr('password'),
                                    prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        color: AppColors.muted),
                                  ),
                                ),
                                if (_register) ...[
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _confirmPassword,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: S.tr('confirmPassword'),
                                      prefixIcon: const Icon(
                                        Icons.lock_person_outlined,
                                        color: AppColors.muted),
                                    ),
                                  ),
                                ],
                                if (!_register)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _loading
                                          ? null
                                          : _showForgotPasswordDialog,
                                      child: Text(S.tr('forgotPassword')),
                                    ),
                                  ),
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.red
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors.red
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: AppColors.redLight,
                                            fontSize: 13)),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 56,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.gradientRedDeep,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.red
                                              .withValues(alpha: 0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed:
                                          _loading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.transparent,
                                        shadowColor:
                                            Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          Colors.white))
                                          : Text(
                                              _register
                                                  ? S.tr('register')
                                                  : S.tr('login'),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() {
                                            _register = !_register;
                                            _error = null;
                                            _confirmPassword.clear();
                                            if (!_register) {
                                              _signupPhoto = null;
                                              _signupPhotoBytes = null;
                                            }
                                          }),
                                  child: Text(
                                    _register
                                        ? S.tr('hasAccount')
                                        : S.tr('noAccount'),
                                    style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
