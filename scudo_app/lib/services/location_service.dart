import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<bool> ensurePermission() async {
    await Permission.location.request();
    var s = await Geolocator.checkPermission();
    if (s == LocationPermission.denied) {
      s = await Geolocator.requestPermission();
    }
    return s == LocationPermission.always || s == LocationPermission.whileInUse;
  }

  static Future<Position?> getCurrent() async {
    final ok = await ensurePermission();
    if (!ok) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  static Stream<Position> watchPosition({
    Duration interval = const Duration(seconds: 3),
  }) async* {
    while (true) {
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        yield p;
      } catch (_) {
        /* posizione non disponibile */
      }
      await Future<void>.delayed(interval);
    }
  }
}
