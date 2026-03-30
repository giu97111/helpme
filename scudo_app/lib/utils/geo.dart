import 'package:geolocator/geolocator.dart';

/// Raggio predefinito per considerare un utente "vicino" (metri).
const double kNearbyRadiusMeters = 500;

double distanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
}

bool isWithinRadius(
  double myLat,
  double myLon,
  double otherLat,
  double otherLon, {
  double radiusMeters = kNearbyRadiusMeters,
}) {
  return distanceMeters(myLat, myLon, otherLat, otherLon) <= radiusMeters;
}
