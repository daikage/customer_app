import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/geo.dart';
import '../widgets/dynamic_map_view.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';

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
    Future.microtask(() {
      ref.read(rideProvider.notifier).fetchActive();
      ref.read(rideProvider.notifier).fetchCategories();
    });
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

  void _showCategorySelection() {
    final categories = ref.read(rideProvider).categories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ride categories available right now.')),
      );
      return;
    }

    final distance = haversineKm(_lat, _lng, _dropoffLat, _dropoffLng);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Ride Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...categories.map((cat) {
                final baseFare = double.parse(cat['base_fare'].toString());
                final perKm = double.parse(cat['per_km_rate'].toString());
                final estFare = baseFare + (distance * perKm);

                return ListTile(
                  leading: const Icon(Icons.directions_car, size: 40),
                  title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Base: ₦$baseFare | Per KM: ₦$perKm'),
                  trailing: Text('~ ₦${estFare.toStringAsFixed(0)}', 
                    style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _bookRide(cat['id']);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<void> _bookRide(int categoryId) async {
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
        categoryId: categoryId,
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

  Future<void> _sendSos(int rideId) async {
    try {
      await ref.read(rideProvider.notifier).sendSos(rideId, _lat, _lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Alert sent! Help is on the way.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showRatingDialog(int rideId) {
    int stars = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rate your Driver'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was your trip?'),
              const SizedBox(height: 16),
              StatefulBuilder(builder: (context, setDialogState) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < stars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setDialogState(() => stars = index + 1);
                      },
                    );
                  }),
                );
              }),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Leave a comment (optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                ref.read(rideProvider.notifier).clear();
              },
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(rideProvider.notifier).rateRide(
                        rideId,
                        stars,
                        commentController.text.trim(),
                      );
                  if (mounted) Navigator.pop(ctx);
                  ref.read(rideProvider.notifier).clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thanks for your feedback!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RideState>(rideProvider, (previous, next) {
      final prevStatus = previous?.ride?['status'];
      final nextStatus = next.ride?['status'];
      if (prevStatus != 'completed' && nextStatus == 'completed') {
        final rideId = next.ride!['id'];
        _showRatingDialog(rideId);
      }
    });

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
                if (isActive) ...[
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'chat',
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                    },
                    child: Icon(Icons.chat,
                        color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'sos',
                    backgroundColor: Colors.red,
                    onPressed: () => _sendSos(ride!['id'] as int),
                    child: const Icon(Icons.emergency, color: Colors.white),
                  ),
                ],
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
                  (isActive || _locating || rideState.loading) ? null : _showCategorySelection,
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
