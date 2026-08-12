import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/geo.dart';

enum MapEngine { google, maplibre }

class MapEngineNotifier extends StateNotifier<MapEngine> {
  MapEngineNotifier() : super(MapEngine.google) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isMapLibre = prefs.getBool('use_maplibre') ?? false;
    state = isMapLibre ? MapEngine.maplibre : MapEngine.google;
  }

  Future<void> toggleEngine() async {
    final prefs = await SharedPreferences.getInstance();
    if (state == MapEngine.google) {
      state = MapEngine.maplibre;
      await prefs.setBool('use_maplibre', true);
    } else {
      state = MapEngine.google;
      await prefs.setBool('use_maplibre', false);
    }
  }
}

final mapEngineProvider = StateNotifierProvider<MapEngineNotifier, MapEngine>((ref) {
  return MapEngineNotifier();
});

/// Immutable snapshot of the live speed computation produced by [SpeedTrackerNotifier].
class SpeedTrackerState {
  final double speedKmh;
  final double? heading;

  const SpeedTrackerState({this.speedKmh = 0, this.heading});

  SpeedTrackerState copyWith({double? speedKmh, double? heading}) =>
      SpeedTrackerState(
        speedKmh: speedKmh ?? this.speedKmh,
        heading: heading ?? this.heading,
      );
}

/// Tracks a moving entity (the driver, as seen by the customer) by collecting
/// the GPS points it reports and deriving a **live speed in km/h** from them.
///
/// The speed is computed purely with the haversine formula over elapsed time
/// between consecutive fixes, so it works even when the backend doesn't push an
/// explicit `speed_kmh` value. The same stream of points also yields a heading
/// (bearing from the travel vector) used to rotate the vehicle marker.
class SpeedTrackerNotifier extends StateNotifier<SpeedTrackerState> {
  SpeedTrackerNotifier() : super(const SpeedTrackerState());

  double? _lastLat;
  double? _lastLng;
  DateTime? _lastTime;

  /// Feed in a new GPS fix for the tracked entity.
  void trackPoint(double lat, double lng, {DateTime? now}) {
    final current = now ?? DateTime.now();

    if (_lastLat != null && _lastLng != null && _lastTime != null) {
      final dKm = haversineKm(_lastLat!, _lastLng!, lat, lng);
      final dtHours = current.difference(_lastTime!).inMilliseconds / 3600000.0;
      if (dtHours > 0) {
        final computed = (dKm / dtHours).clamp(0.0, 200.0);
        state = state.copyWith(speedKmh: computed.toDouble());
      }
    }

    // Heading = bearing from previous fix toward the current fix.
    if (_lastLat != null && _lastLng != null) {
      state = state.copyWith(heading: _bearingTo(_lastLat!, _lastLng!, lat, lng));
    }

    _lastLat = lat;
    _lastLng = lng;
    _lastTime = current;
  }

  /// Stops tracking and resets any accumulated state (e.g. ride finished).
  void reset() {
    _lastLat = null;
    _lastLng = null;
    _lastTime = null;
    state = const SpeedTrackerState();
  }

  static double _bearingTo(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _degToRad(lng2 - lng1);
    final y = sin(dLng) * cos(_degToRad(lat2));
    final x = cos(_degToRad(lat1)) * sin(_degToRad(lat2)) -
        sin(_degToRad(lat1)) * cos(_degToRad(lat2)) * cos(dLng);
    return (_radToDeg(atan2(y, x)) + 360.0) % 360.0;
  }

  static double _degToRad(double deg) => deg * pi / 180.0;
  static double _radToDeg(double rad) => rad * 180.0 / pi;
}

final mapSpeedProvider =
    StateNotifierProvider<SpeedTrackerNotifier, SpeedTrackerState>(
  (ref) => SpeedTrackerNotifier(),
);
