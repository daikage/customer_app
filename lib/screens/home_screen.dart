import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/geo.dart';
import '../widgets/dynamic_map_view.dart';
import 'settings_screen.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _destinationController = TextEditingController();

  double _lat = 6.5244; // Fallback Lagos coords until GPS reports a position
  double _lng = 3.3792;
  bool _locating = true;
  Timer? _pollTimer;

  static const double _dropoffLat = 6.6018; // Ikeja (sample destination)
  static const double _dropoffLng = 3.3515;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    ref.read(rideProvider.notifier).fetchActive();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _lat = position.latitude;
            _lng = position.longitude;
            _locating = false;
          });
        }
      } else if (mounted) {
        setState(() => _locating = false);
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => ref.read(rideProvider.notifier).fetchActive(),
    );
  }

  Future<void> _bookRide() async {
    final notifier = ref.read(rideProvider.notifier);
    final distance = haversineKm(_lat, _lng, _dropoffLat, _dropoffLng);

    try {
      await notifier.requestRide(
        pickupLat: _lat,
        pickupLng: _lng,
        pickupAddress: 'Current location',
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        dropoffAddress: _destinationController.text.trim().isEmpty
            ? 'Destination'
            : _destinationController.text.trim(),
        distanceKm: distance,
      );
      if (mounted) {
        _startPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride requested! Finding a driver...')),
        );
      }
    } catch (_) {
      if (mounted) {
        final error = ref.read(rideProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Could not request ride.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    final ride = rideState.ride;
    final status = ride?['status'] as String?;
    final isActive =
        status != null && !['completed', 'cancelled'].contains(status);

    return Scaffold(
      body: Stack(
        children: [
          DynamicMapView(latitude: _lat, longitude: _lng),
          Positioned(
            top: 50,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'settings',
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                  child: Icon(Icons.settings,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'logout',
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onPressed: _logout,
                  child: Icon(Icons.logout,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          ),
          Positioned(
            top: 50,
            left: 16,
            right: 90,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _destinationController,
                  enabled: !isActive,
                  decoration: const InputDecoration(
                    hintText: 'Where to?',
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
          ),
          if (ride != null)
            Positioned(
              top: 110,
              left: 16,
              right: 16,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.local_taxi, color: Colors.green),
                  title: Text(isActive ? 'Your ride is $status' : 'Ride $status'),
                  subtitle: Text('Estimated fare: ₦${ride['estimated_fare']}'),
                ),
              ),
            ),
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed:
                  (isActive || _locating || rideState.loading) ? null : _bookRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: rideState.loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      ride != null ? 'Ride $status' : 'Book Ride',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
