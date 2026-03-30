import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/glass_container.dart';
import 'responder_map_screen.dart';

class HelpAlertScreen extends StatefulWidget {
  const HelpAlertScreen({super.key, required this.emergencyId});
  final String emergencyId;

  @override
  State<HelpAlertScreen> createState() => _HelpAlertScreenState();
}

class _HelpAlertScreenState extends State<HelpAlertScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _pulse,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AppColors.red.withValues(
                                        alpha: 0.3 + _pulse.value * 0.3,
                                      ),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.red.withValues(
                                          alpha: 0.05 + _pulse.value * 0.08,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3D1111),
                                      Color(0xFF1A0808),
                                    ],
                                  ),
                                ),
                                child: StreamBuilder(
                                  stream: EmergencyService.emergencyStream(
                                    widget.emergencyId,
                                  ),
                                  builder: (context, snap) {
                                    final d = snap.data?.data();
                                    if (d == null) {
                                      return const SizedBox(
                                        height: 200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.red,
                                          ),
                                        ),
                                      );
                                    }
                                    final name =
                                        d['displayName'] as String? ??
                                        S.tr('user');
                                    final lat = (d['lat'] as num?)?.toDouble();
                                    final lng = (d['lng'] as num?)?.toDouble();

                                    return FutureBuilder<Position?>(
                                      future: LocationService.getCurrent(),
                                      builder: (context, posSnap) {
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
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header
                                            Row(
                                              children: [
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient:
                                                        AppColors.gradientRed,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.red
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                        blurRadius: 16,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.warning_amber_rounded,
                                                    color: Colors.white,
                                                    size: 32,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        S.tr('helpRequest'),
                                                        style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color:
                                                              AppColors.white,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        dist != null
                                                            ? S.trWith(
                                                                'approxDistance',
                                                                {
                                                                  'n':
                                                                      '${dist.round()}',
                                                                },
                                                              )
                                                            : S.tr(
                                                                'calculatingDistance',
                                                              ),
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .redLight,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            // Person info
                                            GlassContainer(
                                              padding: const EdgeInsets.all(16),
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration:
                                                            BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: AppColors
                                                                  .red
                                                                  .withValues(
                                                                    alpha: 0.2,
                                                                  ),
                                                            ),
                                                        child: Center(
                                                          child: Text(
                                                            name.isNotEmpty
                                                                ? name[0]
                                                                      .toUpperCase()
                                                                : '?',
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      AppColors
                                                                          .red,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  fontSize: 16,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        name,
                                                        style: const TextStyle(
                                                          color:
                                                              AppColors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    S.tr('activatedAlarm'),
                                                    style: TextStyle(
                                                      color: AppColors.redLight
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                      fontSize: 14,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            // Buttons
                                            SizedBox(
                                              width: double.infinity,
                                              height: 54,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.of(
                                                    context,
                                                  ).pushReplacement(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          ResponderMapScreen(
                                                            emergencyId: widget
                                                                .emergencyId,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.white,
                                                  foregroundColor:
                                                      AppColors.red,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                icon: const Icon(
                                                  Icons.navigation,
                                                ),
                                                label: Text(
                                                  S.tr('seePosition'),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 54,
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  final u = Uri.parse(
                                                    'tel:112',
                                                  );
                                                  if (await canLaunchUrl(u)) {
                                                    await launchUrl(u);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.red,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                icon: const Icon(Icons.phone),
                                                label: Text(
                                                  S.tr('call112'),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    S.tr('ignore'),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
