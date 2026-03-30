import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';

class ResponderMapScreen extends StatefulWidget {
  const ResponderMapScreen({super.key, required this.emergencyId});
  final String emergencyId;

  @override
  State<ResponderMapScreen> createState() =>
      _ResponderMapScreenState();
}

class _ResponderMapScreenState extends State<ResponderMapScreen> {
  final _mapController = MapController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _emSub;
  StreamSubscription<Position>? _meSub;
  Position? _me;
  double? _vLat;
  double? _vLng;
  String _name = '…';
  String? _victimPhotoUrl;
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmergencyOnce();
    _emSub = EmergencyService.emergencyStream(widget.emergencyId)
        .listen(
      (doc) {
        final d = doc.data();
        if (d == null) return;
        final lat = (d['lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble();
        final p = d['photoUrl'] as String?;
        final uid = d['userId'] as String?;
        setState(() {
          _name = d['displayName'] as String? ?? S.tr('user');
          _vLat = lat;
          _vLng = lng;
          _victimPhotoUrl =
              (p != null && p.isNotEmpty) ? p : null;
          _loadError = null;
        });
        _moveMapToVictim();
        _maybeLoadVictimPhotoFromProfile(uid);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      },
    );
    _meSub = LocationService.watchPosition(
            interval: const Duration(seconds: 4))
        .listen(
      (p) => setState(() => _me = p),
      onError: (_) {},
    );
  }

  Future<void> _fetchEmergencyOnce() async {
    try {
      final doc = await EmergencyService.getEmergencyOnce(
              widget.emergencyId)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _loadError = S.tr('emergencyNotFound');
          _loading = false;
        });
        return;
      }
      final d = doc.data();
      final p = d?['photoUrl'] as String?;
      final uid = d?['userId'] as String?;
      setState(() {
        _name = d?['displayName'] as String? ?? S.tr('user');
        _vLat = (d?['lat'] as num?)?.toDouble();
        _vLng = (d?['lng'] as num?)?.toDouble();
        _victimPhotoUrl =
            (p != null && p.isNotEmpty) ? p : null;
        _loading = false;
      });
      _moveMapToVictim();
      _maybeLoadVictimPhotoFromProfile(uid);
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _loadError = S.tr('networkTimeout');
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Se l'emergenza non ha `photoUrl` (es. vecchia), prova `users/{userId}`.
  void _maybeLoadVictimPhotoFromProfile(String? victimUid) {
    if (victimUid == null || victimUid.isEmpty) return;
    if (_victimPhotoUrl != null && _victimPhotoUrl!.isNotEmpty) return;
    UserService.getUserPhotoUrl(victimUid).then((url) {
      if (!mounted || url == null || url.isEmpty) return;
      setState(() {
        if (_victimPhotoUrl == null || _victimPhotoUrl!.isEmpty) {
          _victimPhotoUrl = url;
        }
      });
    });
  }

  void _moveMapToVictim() {
    if (_vLat == null || _vLng == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(LatLng(_vLat!, _vLng!), 16);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _emSub?.cancel();
    _meSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final victim = _vLat != null && _vLng != null
        ? LatLng(_vLat!, _vLng!)
        : null;
    final me = _me != null
        ? LatLng(_me!.latitude, _me!.longitude)
        : null;

    double? dist;
    if (_me != null && _vLat != null && _vLng != null) {
      dist = distanceMeters(
          _me!.latitude, _me!.longitude, _vLat!, _vLng!);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map or state
          if (_loadError != null && victim == null)
            Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.gradientBg),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.red
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.map_outlined,
                            color: AppColors.muted, size: 48),
                      ),
                      const SizedBox(height: 20),
                      Text(_loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 15)),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _loadError = null;
                            _loading = true;
                          });
                          _fetchEmergencyOnce();
                        },
                        icon: const Icon(Icons.refresh,
                            color: AppColors.red),
                        label: Text(S.tr('retry'),
                            style: const TextStyle(
                                color: AppColors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (victim != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: victim,
                initialZoom: 16,
                minZoom: 3,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gio.helpme',
                ),
                MarkerLayer(
                  markers: [
                    // Vittima in pericolo: foto profilo se presente nell'emergenza, altrimenti icona
                    Marker(
                      point: victim,
                      width: 64,
                      height: 68,
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white,
                                  width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.red
                                      .withValues(alpha: 0.6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _victimPhotoUrl != null
                                ? Image.network(
                                    _victimPhotoUrl!,
                                    fit: BoxFit.cover,
                                    width: 44,
                                    height: 44,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.gradientRed,
                                      ),
                                      child: const Icon(
                                        Icons.person_pin_circle,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: AppColors.gradientRed,
                                    ),
                                    child: const Icon(
                                      Icons.person_pin_circle,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                              _name.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Me marker
                    if (me != null)
                      Marker(
                        point: me,
                        width: 50,
                        height: 50,
                        child: Column(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white,
                                    width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.blue
                                        .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                S.tr('you'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight:
                                        FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            )
          else
            Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.gradientBg),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                        color: AppColors.red),
                    const SizedBox(height: 20),
                    Text(
                      _loading
                          ? S.tr('loadingMap')
                          : S.tr('waitingPosition'),
                      style: const TextStyle(
                          color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.95),
                    AppColors.surface.withValues(alpha: 0.0),
                  ],
                  stops: const [0.7, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(4, 8, 16, 20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.border),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: AppColors.white, size: 20),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.trWith(
                                  'reach', {'name': _name}),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dist != null
                                  ? S.trWith('metersAway', {
                                      'n': '${dist.round()}'
                                    })
                                  : S.tr('updatingPosition'),
                              style: const TextStyle(
                                  color: AppColors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      // Distance badge
                      if (dist != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.red
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.red
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${dist.round()} m',
                            style: const TextStyle(
                                color: AppColors.red,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.98),
                    AppColors.surface.withValues(alpha: 0.0),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      20, 30, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
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
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final u = Uri.parse('tel:112');
                              if (await canLaunchUrl(u)) {
                                await launchUrl(u);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.phone),
                            label: Text(S.tr('call112'),
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            side: const BorderSide(
                                color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(S.tr('closeMap'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
