import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/language_sheet.dart';
import 'profile_screen.dart';
import 'sos_active_screen.dart';
import 'sos_countdown_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSos() async {
    final pos = await LocationService.getCurrent();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.tr('locationPermission')),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final go = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SosCountdownScreen(onCancel: () {}),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (go != true || !mounted) return;

    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final name = await UserService.getResolvedDisplayName(u);
    final nameForSos = name.isEmpty ? S.tr('user') : name;
    final photoUrl = await UserService.getUserPhotoUrl(u.uid);

    final id = await EmergencyService.startEmergency(
      userId: u.uid,
      displayName: nameForSos,
      pos: pos,
      photoUrl: photoUrl,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SosActiveScreen(emergencyId: id),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.gradientBg),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      customBorder: const CircleBorder(),
                      child: Ink(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientGlass,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: u?.photoURL != null && u!.photoURL!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  u.photoURL!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          const Icon(
                                    Icons.person,
                                    color: AppColors.muted,
                                    size: 22,
                                  ),
                                ),
                              )
                            : const Icon(Icons.person,
                                color: AppColors.muted, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: u == null
                        ? Text(
                            S.tr('user'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.white,
                            ),
                          )
                        : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: UserService.userDocStream(u.uid),
                            builder: (context, snap) {
                              final raw = UserService.resolveDisplayName(
                                u,
                                snap.data?.data(),
                              );
                              final name = raw.isEmpty ? S.tr('user') : raw;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.green,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.green
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        S.tr('networkActive'),
                                        style: const TextStyle(
                                          color: AppColors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.language, color: AppColors.muted),
                    onPressed: () => showLanguagePickerSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.muted),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  ),
                ],
              ),
            ),

            // Network count (compatto)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: FutureBuilder<int>(
                future: UserService.countUsers(),
                builder: (context, snap) {
                  final label = switch (snap.connectionState) {
                    ConnectionState.waiting => S.tr('networkLoading'),
                    _ when snap.hasError => S.tr('networkActive'),
                    _ => S.trWith('usersOnNetwork', {
                        'n': '${snap.data ?? 0}',
                      }),
                  };
                  return Align(
                    alignment: Alignment.center,
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.green
                                      .withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // SOS a tutto schermo (area centrale), centrato
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final diameter = side * 0.88;
                  final iconSize = diameter * 0.22;
                  final fontSize = diameter * 0.18;
                  return Center(
                    child: AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (context, _) {
                        final glowAlpha =
                            0.22 + _glowCtrl.value * 0.22;
                        return GestureDetector(
                          onTap: _startSos,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: diameter,
                            height: diameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.gradientRedDeep,
                              border: Border.all(
                                color: AppColors.redLight
                                    .withValues(alpha: 0.35),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.red
                                      .withValues(alpha: glowAlpha),
                                  blurRadius: 56,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: AppColors.redDark
                                      .withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: iconSize,
                                ),
                                SizedBox(height: diameter * 0.02),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: diameter * 0.03,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 20),
              child: Text(
                S.tr('sosHint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
