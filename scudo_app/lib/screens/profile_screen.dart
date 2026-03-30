import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/profile_photo_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/language_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _loading = false;
  bool _nameDirty = false;
  late String _nameBaseline;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _nameBaseline = u?.displayName?.trim() ?? '';
    _nameCtrl.text = _nameBaseline;
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final dirty = _nameCtrl.text.trim() != _nameBaseline;
    if (dirty != _nameDirty) setState(() => _nameDirty = dirty);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (x == null || !mounted) return;
      setState(() => _loading = true);
      final url = await ProfilePhotoService.uploadProfilePhoto(u.uid, x);
      await u.updatePhotoURL(url);
      await u.reload();
      await UserService.syncProfile(FirebaseAuth.instance.currentUser!);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.tr('profileSaved')),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[Profile] photo: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.tr('photoUploadError')),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.white),
              title: Text(S.tr('chooseFromGallery'),
                  style: const TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.white),
              title: Text(S.tr('takePhoto'),
                  style: const TextStyle(color: AppColors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _hasPasswordProvider() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    return u.providerData.any((p) => p.providerId == 'password');
  }

  void _showChangePasswordSheet() {
    if (!_hasPasswordProvider()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.tr('changePasswordOnlyEmail')),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _ChangePasswordSheet(
          onSuccess: () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(S.tr('changePasswordSuccess')),
                  backgroundColor: AppColors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.tr('insertName'))),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await u.updateDisplayName(name);
      await u.reload();
      await UserService.syncProfile(FirebaseAuth.instance.currentUser!);
      if (!mounted) return;
      _nameBaseline = _nameCtrl.text.trim();
      setState(() {
        _loading = false;
        _nameDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.tr('profileSaved')),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          S.tr('profile'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: UserService.userDocStream(uid),
                        builder: (context, snap) {
                          final user = FirebaseAuth.instance.currentUser;
                          final data = snap.data?.data();
                          final photoUrl = user?.photoURL ??
                              (data?['photoUrl'] as String?);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: GestureDetector(
                                  onTap: _loading ? null : _showPhotoOptions,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.border,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.red
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 20,
                                            ),
                                          ],
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: photoUrl != null &&
                                                photoUrl.isNotEmpty
                                            ? Image.network(
                                                photoUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, st) =>
                                                        _avatarPlaceholder(),
                                              )
                                            : _avatarPlaceholder(),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: AppColors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  S.tr('tapToAddPhoto'),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                S.tr('accountSection'),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GlassContainer(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _nameCtrl,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: S.tr('yourName'),
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      S.tr('email'),
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      user?.email ?? '—',
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              GlassContainer(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                child: ListTile(
                                  leading: Text(
                                    S.localeFlags[
                                            S.locale.value.languageCode] ??
                                        '',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(
                                    S.tr('language'),
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    S.localeLabels[
                                            S.locale.value.languageCode] ??
                                        '',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.muted,
                                  ),
                                  onTap: () => showLanguagePickerSheet(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GlassContainer(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.muted,
                                  ),
                                  title: Text(
                                    S.tr('changePassword'),
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.muted,
                                  ),
                                  onTap: _loading ? null : _showChangePasswordSheet,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.gradientRedDeep,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _loading || !_nameDirty
                                        ? null
                                        : _saveName,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          AppColors.border,
                                    ),
                                    child: Text(
                                      S.tr('saveChanges'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppColors.card,
      child: const Icon(
        Icons.person,
        size: 56,
        color: AppColors.muted,
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_new.text.length < 8) {
      setState(() => _error = S.tr('passwordTooShort'));
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = S.tr('passwordMismatch'));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final u = FirebaseAuth.instance.currentUser;
      final email = u?.email;
      if (u == null || email == null) return;
      final cred = EmailAuthProvider.credential(
        email: email,
        password: _current.text,
      );
      await u.reauthenticateWithCredential(cred);
      await u.updatePassword(_new.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _error = S.tr('changePasswordWrongCurrent');
        } else if (e.code == 'weak-password') {
          _error = S.tr('passwordTooShort');
        } else {
          _error = e.message ?? S.tr('changePasswordError');
        }
      });
    } catch (_) {
      setState(() => _error = S.tr('changePasswordError'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.tr('changePassword'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _current,
              obscureText: true,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: S.tr('currentPassword'),
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _new,
              obscureText: true,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: S.tr('newPassword'),
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: S.tr('confirmNewPassword'),
                prefixIcon:
                    const Icon(Icons.lock_person_outlined, color: AppColors.muted),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.redLight, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(S.tr('saveChanges')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(S.tr('cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
