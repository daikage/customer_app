import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
