import 'package:dio/dio.dart';

class RouteService {
  static final Dio _dio = Dio();

  /// Fetches a route using OSRM's public API and returns a list of [lat, lng] coordinates
  static Future<List<List<double>>> getRouteCoordinates(
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
          return _decodePolyline(geometry);
        }
      }
    } catch (e) {
      // Return empty list on failure
    }
    return [];
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
