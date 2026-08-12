import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import '../providers/map_provider.dart';

/// A single position indicator ("gizmo") shown on the map — the current user,
/// the assigned driver, the customer, or a pickup/dropoff point.
class MapPin {
  final double latitude;
  final double longitude;
  final Color color;
  final String? label;

  const MapPin({
    required this.latitude,
    required this.longitude,
    required this.color,
    this.label,
  });

  /// Stable signature used to detect pin changes without needless redraws.
  String get signature =>
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)},${color.toARGB32()},$label';
}

class DynamicMapView extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;
  final Set<gm.Marker> googleMarkers;
  final List<MapPin> pins;
  final List<List<double>>? routeCoordinates;

  const DynamicMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.googleMarkers = const {},
    this.pins = const [],
    this.routeCoordinates,
  });

  @override
  ConsumerState<DynamicMapView> createState() => _DynamicMapViewState();
}

class _DynamicMapViewState extends ConsumerState<DynamicMapView> {
  ml.MapLibreMapController? _mlController;
  String _lastMapLibreSignature = '';

  @override
  void didUpdateWidget(DynamicMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // MapLibre is imperative, so redraw the shapes when pins/route change.
    final controller = _mlController;
    if (controller == null) return;

    final signature = _mapLibreSignature();
    if (signature != _lastMapLibreSignature) {
      _lastMapLibreSignature = signature;
      _drawMapLibre(controller);
    }
  }

  String _mapLibreSignature() {
    final pins = widget.pins.map((p) => p.signature).join('|');
    final route = (widget.routeCoordinates ?? const [])
        .map((c) => '${c[0]},${c[1]}')
        .join('|');
    return '$pins|$route';
  }

  Future<void> _drawMapLibre(ml.MapLibreMapController controller) async {
    try {
      await controller.clearCircles();
      await controller.clearLines();

      for (final pin in widget.pins) {
        await controller.addCircle(ml.CircleOptions(
          geometry: ml.LatLng(pin.latitude, pin.longitude),
          circleRadius: 9.0,
          circleColor: _hexFromColor(pin.color),
          circleStrokeWidth: 2.5,
          circleStrokeColor: '#FFFFFF',
        ));
      }

      // Legacy markers passed through the Google abstraction.
      for (final marker in widget.googleMarkers) {
        await controller.addCircle(ml.CircleOptions(
          geometry: ml.LatLng(marker.position.latitude, marker.position.longitude),
          circleRadius: 8.0,
          circleColor: '#FF0000',
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
        ));
      }

      if (widget.routeCoordinates != null && widget.routeCoordinates!.isNotEmpty) {
        await controller.addLine(ml.LineOptions(
          geometry: widget.routeCoordinates!
              .map((c) => ml.LatLng(c[0], c[1]))
              .toList(),
          lineColor: '#0D7377',
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ));
      }
    } catch (_) {
      // Ignore transient render errors (e.g. during a live redraw).
    }
  }

  String _hexFromColor(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  double _hueFromColor(Color color) => HSLColor.fromColor(color).hue;

  Set<gm.Marker> _buildGoogleMarkers() {
    final markers = <gm.Marker>{...widget.googleMarkers};
    for (var i = 0; i < widget.pins.length; i++) {
      final pin = widget.pins[i];
      markers.add(gm.Marker(
        markerId: gm.MarkerId('pin_${i}_${_hexFromColor(pin.color)}'),
        position: gm.LatLng(pin.latitude, pin.longitude),
        infoWindow: gm.InfoWindow(title: pin.label ?? ''),
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(_hueFromColor(pin.color)),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final mapEngine = ref.watch(mapEngineProvider);

    if (mapEngine == MapEngine.google) {
      return gm.GoogleMap(
        initialCameraPosition: gm.CameraPosition(
          target: gm.LatLng(widget.latitude, widget.longitude),
          zoom: 14.0,
        ),
        markers: _buildGoogleMarkers(),
        polylines: widget.routeCoordinates != null && widget.routeCoordinates!.isNotEmpty
            ? {
                gm.Polyline(
                  polylineId: const gm.PolylineId('route'),
                  points: widget.routeCoordinates!
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
    }

    return ml.MapLibreMap(
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(widget.latitude, widget.longitude),
        zoom: 14.0,
      ),
      styleString: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
      myLocationEnabled: true,
      myLocationRenderMode: ml.MyLocationRenderMode.normal,
      onMapCreated: (controller) {
        _mlController = controller;
        _lastMapLibreSignature = _mapLibreSignature();
        _drawMapLibre(controller);
      },
    );
  }
}
