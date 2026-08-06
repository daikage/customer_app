import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import '../providers/map_provider.dart';

class DynamicMapView extends ConsumerWidget {
  final double latitude;
  final double longitude;
  final Set<gm.Marker> googleMarkers;

  const DynamicMapView({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.googleMarkers = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapEngine = ref.watch(mapEngineProvider);

    if (mapEngine == MapEngine.google) {
      return gm.GoogleMap(
        initialCameraPosition: gm.CameraPosition(
          target: gm.LatLng(latitude, longitude),
          zoom: 14.0,
        ),
        markers: googleMarkers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      );
    } else {
      return ml.MapLibreMap(
        initialCameraPosition: ml.CameraPosition(
          target: ml.LatLng(latitude, longitude),
          zoom: 14.0,
        ),
        styleString: 'https://demotiles.maplibre.org/style.json',
        myLocationEnabled: true,
        myLocationRenderMode: ml.MyLocationRenderMode.normal,
        onMapCreated: (ml.MapLibreMapController controller) {
          for (var marker in googleMarkers) {
            controller.addSymbol(ml.SymbolOptions(
              geometry: ml.LatLng(marker.position.latitude, marker.position.longitude),
              iconImage: 'marker-15',
              iconSize: 2.0,
            ));
          }
        },
      );
    }
  }
}
