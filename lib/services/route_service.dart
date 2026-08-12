import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// A colored chunk of the route used to render a live, traffic-aware line.
class RouteSegment {
  final List<List<double>> points;
  final Color color;

  const RouteSegment(this.points, this.color);
}

/// Map a live speed (km/h) to a traffic-style color: green (fast), amber
/// (moderate), red (slow). Returns a neutral color when speed is unknown.
Color speedToColor(double? speedKmh) {
  final s = speedKmh;
  if (s == null) return const Color(0xFF0D7377); // neutral / default
  if (s >= 25) return const Color(0xFF2ECC71); // green — flowing
  if (s >= 10) return const Color(0xFFF5A623); // amber — slowing
  return const Color(0xFFE74C3C); // red — congested
}

/// Splits a full route into contiguous [segmentCount] colored chunks that
/// form a live gradient: the leading chunks take the current speed color and
/// it fades toward a neutral tail color further ahead.
List<RouteSegment> buildRouteSegments({
  required List<List<double>> route,
  double? speedKmh,
  int segmentCount = 6,
}) {
  if (route.length < 2 || segmentCount <= 1) return const [];

  final status = speedToColor(speedKmh);
  const tail = Color(0xFF607D8B);
  final len = route.length;
  final perChunk = (len - 1) / segmentCount;
  final segments = <RouteSegment>[];

  for (var k = 0; k < segmentCount; k++) {
    final a = ((k * perChunk).round()).clamp(0, len - 2).toInt();
    final b = (((k + 1) * perChunk + 1).round()).clamp(a + 1, len).toInt();
    final color = Color.lerp(status, tail, k / (segmentCount - 1))!;
    segments.add(RouteSegment(route.sublist(a, b), color));
  }
  return segments;
}

/// Snaps a raw GPS position to the nearest vertex on a route so the vehicle
/// marker appears to travel along the line.
List<double> snapToRoute({
  required double lat,
  required double lng,
  required List<List<double>> route,
}) {
  if (route.isEmpty) return [lat, lng];
  var best = route.first;
  var bestSq = double.infinity;
  for (final p in route) {
    final dSq = (p[0] - lat) * (p[0] - lat) + (p[1] - lng) * (p[1] - lng);
    if (dSq < bestSq) {
      bestSq = dSq;
      best = p;
    }
  }
  return best;
}

class RouteInfo {
  final List<List<double>> coordinates;
  final double durationSeconds;

  RouteInfo(this.coordinates, this.durationSeconds);
}

class RouteService {
  static final Dio _dio = Dio();

  /// Fetches a route using OSRM's public API and returns RouteInfo
  static Future<RouteInfo?> getRouteInfo(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?geometries=polyline';
      final response = await _dio.get(url);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'] as String;
          final duration = (data['routes'][0]['duration'] as num).toDouble();
          final coords = _decodePolyline(geometry);
          return RouteInfo(coords, duration);
        }
      }
    } catch (e) {
      // Return null on failure
    }
    return null;
  }

  /// Keep old method for backward compatibility
  static Future<List<List<double>>> getRouteCoordinates(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final info = await getRouteInfo(startLat, startLng, endLat, endLng);
    return info?.coordinates ?? [];
  }

  /// Decodes an encoded polyline string into a list of lat/lng points.
  static List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add([(lat / 1E5).toDouble(), (lng / 1E5).toDouble()]);
    }
    return poly;
  }
}
