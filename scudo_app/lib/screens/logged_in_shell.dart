import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../services/account_deletion_guard.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import 'active_emergencies_screen.dart';
import 'help_alert_screen.dart';
import 'home_screen.dart';

class LoggedInShell extends StatefulWidget {
  const LoggedInShell({super.key});
  @override
  State<LoggedInShell> createState() => _LoggedInShellState();
}

class _LoggedInShellState extends State<LoggedInShell> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _emSub;
  StreamSubscription<Position>? _posSub;
  final _shownEmergencyIds = <String>{};
  int _currentTab = 0;
  int _nearbyEmergencyCount = 0;

  @override
  void initState() {
    super.initState();
    _posSub = LocationService.watchPosition(
            interval: const Duration(seconds: 12))
        .listen(
      (p) async {
        try {
          if (AccountDeletionGuard.inProgress) return;
          final u = FirebaseAuth.instance.currentUser;
          if (u != null) await UserService.updateLocation(u.uid, p);
        } catch (e) {
          debugPrint('[LoggedInShell] updateLocation: $e');
        }
      },
      onError: (Object e) =>
          debugPrint('[LoggedInShell] pos stream: $e'),
    );

    _emSub = EmergencyService.activeEmergenciesStream().listen(
      _onEmergencies,
      onError: (Object e) =>
          debugPrint('[LoggedInShell] emergencies stream: $e'),
    );
  }

  Future<void> _onEmergencies(
      QuerySnapshot<Map<String, dynamic>> snap) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['status'] != 'active') {
        _shownEmergencyIds.remove(doc.id);
      }
    }

    final myPos = await LocationService.getCurrent();
    if (!mounted || myPos == null) return;

    int nearbyCount = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['userId'] == uid) continue;
      if (d['status'] != 'active') continue;
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      if (!isWithinRadius(myPos.latitude, myPos.longitude, lat, lng)) {
        continue;
      }

      nearbyCount++;

      if (_shownEmergencyIds.contains(doc.id)) continue;
      _shownEmergencyIds.add(doc.id);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => HelpAlertScreen(emergencyId: doc.id),
          ),
        );
      });
    }

    if (mounted && nearbyCount != _nearbyEmergencyCount) {
      setState(() => _nearbyEmergencyCount = nearbyCount);
    }
  }

  @override
  void dispose() {
    _emSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const ActiveEmergenciesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.shield_outlined,
                  activeIcon: Icons.shield,
                  label: S.tr('home'),
                  isActive: _currentTab == 0,
                  onTap: () => setState(() => _currentTab = 0),
                ),
                _NavItem(
                  icon: Icons.warning_amber_outlined,
                  activeIcon: Icons.warning_amber_rounded,
                  label: S.tr('emergencies'),
                  isActive: _currentTab == 1,
                  badge: _nearbyEmergencyCount > 0
                      ? _nearbyEmergencyCount
                      : null,
                  onTap: () {
                    unawaited(NotificationService.clearLauncherBadge());
                    setState(() => _currentTab = 1);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isActive
                        ? AppColors.red.withValues(alpha: 0.12)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppColors.red : AppColors.muted,
                    size: 24,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                          minWidth: 18, minHeight: 18),
                      child: Text(
                        '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.red : AppColors.muted,
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
