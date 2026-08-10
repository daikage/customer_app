import 'package:dio/dio.dart';

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
