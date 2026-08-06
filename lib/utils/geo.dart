import 'dart:math';

/// Compute the great-circle distance in kilometres between two coordinates.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);

  final a = pow(sin(dLat / 2), 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * pow(sin(dLng / 2), 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _degToRad(double deg) => deg * pi / 180;
