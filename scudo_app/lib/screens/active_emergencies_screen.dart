import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import 'responder_map_screen.dart';

class ActiveEmergenciesScreen extends StatefulWidget {
  const ActiveEmergenciesScreen({super.key});
  @override
  State<ActiveEmergenciesScreen> createState() =>
      _ActiveEmergenciesScreenState();
}

class _ActiveEmergenciesScreenState extends State<ActiveEmergenciesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inHours > 0) {
      return '${diff.inHours} ${S.tr('hours')} ${S.tr('ago')}';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${S.tr('minutes')} ${S.tr('ago')}';
    }
    return '${diff.inSeconds} ${S.tr('seconds')} ${S.tr('ago')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.gradientBg),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.red, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.tr('activeEmergencies'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white)),
                        const SizedBox(height: 2),
                        Text(S.tr('peopleInDanger'),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Emergency list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: EmergencyService.activeEmergenciesStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.red),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  final uid =
                      FirebaseAuth.instance.currentUser?.uid;

                  final activeEmergencies = docs.where((doc) {
                    final d = doc.data();
                    return d['status'] == 'active' &&
                        d['userId'] != uid;
                  }).toList();

                  if (activeEmergencies.isEmpty) {
                    return _EmptyState(pulse: _pulse);
                  }

                  return FutureBuilder<Position?>(
                    future: LocationService.getCurrent(),
                    builder: (context, posSnap) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            20, 8, 20, 20),
                        itemCount: activeEmergencies.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = activeEmergencies[index];
                          final d = doc.data();
                          final name = d['displayName']
                                  as String? ??
                              S.tr('user');
                          final lat =
                              (d['lat'] as num?)?.toDouble();
                          final lng =
                              (d['lng'] as num?)?.toDouble();
                          final createdAt =
                              d['createdAt'] as Timestamp?;

                          double? dist;
                          if (posSnap.hasData &&
                              lat != null &&
                              lng != null) {
                            dist = distanceMeters(
                              posSnap.data!.latitude,
                              posSnap.data!.longitude,
                              lat,
                              lng,
                            );
                          }

                          return _EmergencyCard(
                            name: name,
                            distance: dist,
                            timeAgo: _timeAgo(createdAt),
                            pulse: _pulse,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ResponderMapScreen(
                                          emergencyId: doc.id),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.pulse});
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.green.withValues(
                        alpha: 0.08 + pulse.value * 0.04),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: AppColors.green
                        .withValues(alpha: 0.6 + pulse.value * 0.4),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              S.tr('everyoneSafe'),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              S.tr('noActiveEmergencies'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({
    required this.name,
    required this.distance,
    required this.timeAgo,
    required this.pulse,
    required this.onTap,
  });

  final String name;
  final double? distance;
  final String timeAgo;
  final AnimationController pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.red.withValues(
                      alpha: 0.08 + pulse.value * 0.04),
                  AppColors.card.withValues(alpha: 0.8),
                ],
              ),
              border: Border.all(
                color: AppColors.red.withValues(
                    alpha: 0.15 + pulse.value * 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.red
                      .withValues(alpha: 0.05 + pulse.value * 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.red
                        .withValues(alpha: 0.15 + pulse.value * 0.1),
                    border: Border.all(
                      color: AppColors.red
                          .withValues(alpha: 0.3 + pulse.value * 0.2),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.red,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.red.withValues(
                                      alpha:
                                          0.3 + pulse.value * 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (distance != null) ...[
                            Icon(Icons.near_me,
                                size: 14,
                                color: AppColors.red
                                    .withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Text(
                              '${distance!.round()} m',
                              style: const TextStyle(
                                  color: AppColors.redLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (timeAgo.isNotEmpty) ...[
                            const Icon(Icons.access_time,
                                size: 14,
                                color: AppColors.muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(timeAgo,
                                  style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: AppColors.red, size: 20),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
