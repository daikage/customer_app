import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import '../providers/map_provider.dart';

class DynamicMapView extends ConsumerWidget {
  final double latitude;
  final double longitude;
  final Set<gm.Marker> googleMarkers;
  final List<List<double>>? routeCoordinates;

  const DynamicMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.googleMarkers = const {},
    this.routeCoordinates,
  });

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
        polylines: routeCoordinates != null && routeCoordinates!.isNotEmpty
            ? {
                gm.Polyline(
                  polylineId: const gm.PolylineId('route'),
                  points: routeCoordinates!
                      .map((c) => gm.LatLng(c[0], c[1]))
                      .toList(),
                  color: const Color(0xFF0D7377),
                  width: 5,
                )
              }
            : {},
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
        styleString: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
        myLocationEnabled: true,
        myLocationRenderMode: ml.MyLocationRenderMode.normal,
        onMapCreated: (ml.MapLibreMapController controller) {
          for (var marker in googleMarkers) {
            controller.addCircle(ml.CircleOptions(
              geometry: ml.LatLng(marker.position.latitude, marker.position.longitude),
              circleRadius: 8.0,
              circleColor: '#FF0000', // Red circle for markers
              circleStrokeWidth: 2.0,
              circleStrokeColor: '#FFFFFF',
            ));
          }

          if (routeCoordinates != null && routeCoordinates!.isNotEmpty) {
            controller.addLine(ml.LineOptions(
              geometry: routeCoordinates!
                  .map((c) => ml.LatLng(c[0], c[1]))
                  .toList(),
              lineColor: '#0D7377',
              lineWidth: 5.0,
              lineOpacity: 0.8,
            ));
          }
        },
      );
    }
  }
}
