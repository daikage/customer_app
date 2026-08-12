import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/dynamic_map_view.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'address_search_screen.dart';
import 'wallet_screen.dart';
import '../services/route_service.dart';
import '../providers/map_provider.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  final _destinationController = TextEditingController();

  // Service-type-specific controllers
  final _cargoDescController = TextEditingController();
  final _cargoWeightController = TextEditingController();
  final _packageDescController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _destStateController = TextEditingController();
  final _numPassengersController = TextEditingController();

  String _selectedHaulageVehicle = 'van';

  double _lat = 6.5244;
  double _lng = 3.3792;
  bool _locating = true;
  Timer? _pollTimer;

  double? _dropoffLat;
  double? _dropoffLng;
  List<List<double>>? _currentRoute;
  List<List<double>>? _driverRoute;
  String? _driverEta;

  late AnimationController _fabAnimController;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _determinePosition();
    Future.microtask(() {
      ref.read(rideProvider.notifier).fetchActive();
      ref.read(rideProvider.notifier).fetchCategories(serviceType: 'single');
    });
    _fabAnimController.forward();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _destinationController.dispose();
    _cargoDescController.dispose();
    _cargoWeightController.dispose();
    _packageDescController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _destStateController.dispose();
    _numPassengersController.dispose();
    _fabAnimController.dispose();
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
      (_) {
        final notifier = ref.read(rideProvider.notifier);
        notifier.fetchActive();

        // Share the customer's live position while a ride is active so the
        // assigned driver can see them moving on the map.
        final ride = ref.read(rideProvider).ride;
        if (ride != null) {
          final status = ride['status'] as String?;
          if (status != null &&
              status != 'pending' &&
              status != 'completed' &&
              status != 'cancelled') {
            notifier.updateCustomerLocation(ride['id'] as int, _lat, _lng);
          }
        }
      },
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Position pins for the assigned driver's live location (fed by the 5s poll
  /// and realtime DriverLocationUpdated events).
  List<MapPin> _ridePins(Map<String, dynamic> ride) {
    final driver = ride['driver'];
    if (driver is Map) {
      final lat = double.tryParse(driver['last_lat']?.toString() ?? '');
      final lng = double.tryParse(driver['last_lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        return [
          MapPin(
            latitude: lat,
            longitude: lng,
            color: AppColors.success,
            label: 'Driver',
          ),
        ];
      }
    }
    return const [];
  }

  Map<String, dynamic>? _buildServiceMeta(String serviceType) {
    switch (serviceType) {
      case 'haulage':
        return {
          'cargo_description': _cargoDescController.text.trim(),
          'cargo_weight_kg': double.tryParse(_cargoWeightController.text) ?? 0,
          'vehicle_type_required': _selectedHaulageVehicle,
        };
      case 'dispatch':
        return {
          'package_description': _packageDescController.text.trim(),
          'recipient_name': _recipientNameController.text.trim(),
          'recipient_phone': _recipientPhoneController.text.trim(),
        };
      case 'interstate':
        return {
          'destination_state': _destStateController.text.trim(),
          'num_passengers': int.tryParse(_numPassengersController.text) ?? 1,
        };
      default:
        return null;
    }
  }

  void _showCategorySelection() {
    final rideState = ref.read(rideProvider);
    final categories = rideState.categories;
    final serviceType = rideState.selectedServiceType;

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No categories available for this service type.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final distance = haversineKm(_lat, _lng, _dropoffLat ?? _lat, _dropoffLng ?? _lng);
    final stColor = serviceTypeColor(serviceType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: stColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(serviceTypeIcon(serviceType), color: stColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select ${serviceTypeLabel(serviceType)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${distance.toStringAsFixed(1)} km trip',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...categories.map((cat) {
                final baseFare = double.parse(cat['base_fare'].toString());
                final perKm = double.parse(cat['per_km_rate'].toString());
                final estFare = baseFare + (distance * perKm);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(ctx);
                        _bookRide(cat['id'], serviceType);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: AppGradients.serviceType(serviceType),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                categoryIcon(cat['name']),
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Base ₦${baseFare.toStringAsFixed(0)} · ₦${perKm.toStringAsFixed(0)}/km',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: stColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '₦${estFare.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: stColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _bookRide(int categoryId, String serviceType) async {
    final notifier = ref.read(rideProvider.notifier);
    final distance = haversineKm(_lat, _lng, _dropoffLat ?? _lat, _dropoffLng ?? _lng);

    try {
      await notifier.requestRide(
        pickupLat: _lat,
        pickupLng: _lng,
        pickupAddress: 'Current location',
        dropoffLat: _dropoffLat ?? _lat,
        dropoffLng: _dropoffLng ?? _lng,
        dropoffAddress: _destinationController.text.trim().isEmpty
            ? 'Destination'
            : _destinationController.text.trim(),
        distanceKm: distance,
        categoryId: categoryId,
        serviceType: serviceType,
        serviceMeta: _buildServiceMeta(serviceType),
      );
      if (mounted) {
        _startPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ride requested! Finding a driver...'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        final error = ref.read(rideProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Could not request ride.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
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
          SnackBar(
            content: const Text('SOS Alert sent! Help is on the way.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Rate your Driver', style: TextStyle(fontWeight: FontWeight.w700)),
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
                        index < stars ? Icons.star_rounded : Icons.star_border_rounded,
                        color: AppColors.accent,
                        size: 36,
                      ),
                      onPressed: () {
                        setDialogState(() => stars = index + 1);
                      },
                    );
                  }),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
              child: Text('Skip', style: TextStyle(color: Colors.grey.shade500)),
            ),
            FilledButton(
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
                      SnackBar(
                        content: const Text('Thanks for your feedback!'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
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
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchDriverEtaIfNeeded(Map<String, dynamic> ride) async {
    final status = ride['status'] as String;
    if (!['accepted', 'arrived', 'started'].contains(status)) {
      if (mounted) {
        setState(() {
          _driverEta = null;
          _driverRoute = null;
        });
      }
      return;
    }

    final driverLatStr = ride['driver']?['last_lat']?.toString();
    final driverLngStr = ride['driver']?['last_lng']?.toString();
    final dropLatStr = ride['dropoff_lat']?.toString();
    final dropLngStr = ride['dropoff_lng']?.toString();
    final pickLatStr = ride['pickup_lat']?.toString();
    final pickLngStr = ride['pickup_lng']?.toString();

    if (driverLatStr != null && driverLngStr != null) {
      final driverLat = double.tryParse(driverLatStr);
      final driverLng = double.tryParse(driverLngStr);
      final dropLat = double.tryParse(dropLatStr ?? '');
      final dropLng = double.tryParse(dropLngStr ?? '');
      final pickLat = double.tryParse(pickLatStr ?? '');
      final pickLng = double.tryParse(pickLngStr ?? '');

      if (driverLat != null && driverLng != null) {
        // If driver is accepted, ETA to pickup. If started, ETA to dropoff.
        final destLat = (status == 'started') ? dropLat : pickLat;
        final destLng = (status == 'started') ? dropLng : pickLng;

        if (destLat != null && destLng != null) {
          final info = await RouteService.getRouteInfo(driverLat, driverLng, destLat, destLng);
          if (info != null && mounted) {
            final mins = (info.durationSeconds / 60).ceil();
            setState(() {
              _driverRoute = info.coordinates;
              _driverEta = '$mins min${mins > 1 ? 's' : ''}';
            });
          }
        }
      }
    }
  }

  // ─── Service type specific fields ────────────────────────────────────────

  Widget _buildServiceFields(String serviceType) {
    switch (serviceType) {
      case 'haulage':
        return _buildHaulageFields();
      case 'dispatch':
        return _buildDispatchFields();
      case 'interstate':
        return _buildInterstateFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHaulageFields() {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildGlassInput(
          controller: _cargoDescController,
          hint: 'Cargo description',
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildGlassInput(
                controller: _cargoWeightController,
                hint: 'Weight (kg)',
                icon: Icons.scale_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.soft,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedHaulageVehicle,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more),
                    items: const [
                      DropdownMenuItem(value: 'van', child: Text('Van')),
                      DropdownMenuItem(value: 'truck', child: Text('Truck')),
                      DropdownMenuItem(value: 'flatbed', child: Text('Flatbed')),
                    ],
                    onChanged: (v) => setState(() => _selectedHaulageVehicle = v ?? 'van'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDispatchFields() {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildGlassInput(
          controller: _packageDescController,
          hint: 'Package description',
          icon: Icons.inventory_outlined,
        ),
        const SizedBox(height: 8),
        _buildGlassInput(
          controller: _recipientNameController,
          hint: 'Recipient name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 8),
        _buildGlassInput(
          controller: _recipientPhoneController,
          hint: 'Recipient phone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildInterstateFields() {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildGlassInput(
          controller: _destStateController,
          hint: 'Destination state',
          icon: Icons.location_city_outlined,
        ),
        const SizedBox(height: 8),
        _buildGlassInput(
          controller: _numPassengersController,
          hint: 'Number of passengers',
          icon: Icons.people_outline,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.soft,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
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

      // Update ETA if driver location or status changes
      if (next.ride != null) {
        final prevLat = previous?.ride?['driver']?['last_lat'];
        final prevLng = previous?.ride?['driver']?['last_lng'];
        final nextLat = next.ride!['driver']?['last_lat'];
        final nextLng = next.ride!['driver']?['last_lng'];

        if (prevStatus != nextStatus || prevLat != nextLat || prevLng != nextLng) {
          _fetchDriverEtaIfNeeded(next.ride!);
        }
      } else {
        if (mounted) {
          setState(() {
            _driverEta = null;
            _driverRoute = null;
          });
          ref.read(mapSpeedProvider.notifier).reset();
        }
      }

      // Poll while a ride is live, stop once it ends or is cleared. This keeps
      // the customer UI in sync even when the socket is unavailable.
      final hasLiveRide =
          next.ride != null && nextStatus != 'completed' && nextStatus != 'cancelled';
      if (hasLiveRide) {
        _startPolling();
      } else {
        _stopPolling();
      }
    });

    final rideState = ref.watch(rideProvider);
    final ride = rideState.ride;
    final status = ride?['status'] as String?;
    final isActive = status != null && !['completed', 'cancelled'].contains(status);
    final selectedType = rideState.selectedServiceType;
    final stColor = serviceTypeColor(selectedType);

    /// Live speed (km/h) of the driver, computed from the stream of GPS fixes
    /// the customer receives. Drives the route-segment coloring below.
    final driverSpeed = ref.watch(mapSpeedProvider).speedKmh;

    // While a ride is active, follow the driver's position along its route so
    // the vehicle marker "sticks" to the path and the line reflects the live
    // speed (green -> amber -> red).
    List<double>? driverPos;
    List<RouteSegment> routeSegments = const [];
    if (ride != null) {
      final d = ride['driver'];
      if (d is Map) {
        final dLat = double.tryParse(d['last_lat']?.toString() ?? '');
        final dLng = double.tryParse(d['last_lng']?.toString() ?? '');
        if (dLat != null && dLng != null) {
          if (_driverRoute != null) {
            driverPos = snapToRoute(lat: dLat, lng: dLng, route: _driverRoute!);
            routeSegments = buildRouteSegments(
              route: _driverRoute!,
              speedKmh: driverSpeed,
            );
          } else {
            driverPos = [dLat, dLng];
          }
        }
      }
    }

    // Outside an active ride, keep the preview route colored but neutral.
    if (routeSegments.isEmpty && _currentRoute != null) {
      routeSegments = buildRouteSegments(route: _currentRoute!, speedKmh: null);
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────
          DynamicMapView(
            latitude: driverPos?[0] ?? _lat,
            longitude: driverPos?[1] ?? _lng,
            routeCoordinates: _currentRoute,
            routeSegments: routeSegments,
            pins: [
              MapPin(
                latitude: _lat,
                longitude: _lng,
                color: AppColors.info,
                label: 'You',
              ),
              if (_dropoffLat != null && _dropoffLng != null)
                MapPin(
                  latitude: _dropoffLat!,
                  longitude: _dropoffLng!,
                  color: AppColors.accent,
                  label: _destinationController.text.trim().isEmpty
                      ? 'Destination'
                      : _destinationController.text.trim(),
                ),
              if (driverPos != null)
                MapPin(
                  latitude: driverPos![0],
                  longitude: driverPos![1],
                  color: AppColors.success,
                  label: 'Driver',
                  isVehicle: true,
                  radius: 13.0,
                ),
            ],
          ),

          // ── Top gradient overlay ──────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Search bar ────────────────────────────────────────────
          Positioned(
            top: 56,
            left: 16,
            right: 80,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: isActive
                    ? null
                    : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          final lat = result['lat'] as double;
                          final lng = result['lng'] as double;
                          setState(() {
                            _destinationController.text = result['address'] as String;
                            _dropoffLat = lat;
                            _dropoffLng = lng;
                            _currentRoute = null; // Clear existing route while fetching
                          });

                          // Fetch route using OSRM
                          if (_lat != 0.0 && _lng != 0.0) {
                            final route =
                                await RouteService.getRouteCoordinates(_lat, _lng, lat, lng);
                            if (mounted) {
                              setState(() => _currentRoute = route);
                            }
                          }
                        }
                      },
                child: AbsorbPointer(
                  child: TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'Where to?',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      prefixIcon: Icon(Icons.search_rounded, color: stColor, size: 22),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ),
          ).animate().fade().slideY(begin: -0.2, end: 0),

          // ── FAB column ────────────────────────────────────────────
          Positioned(
            top: 56,
            right: 16,
            child: FadeTransition(
              opacity: _fabAnimController,
              child: Column(
                children: [
                  _buildGlassFAB(
                    heroTag: 'history',
                    icon: Icons.history_rounded,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ).animate().scale(delay: 200.ms),
                  const SizedBox(height: 10),
                  _buildGlassFAB(
                    heroTag: 'wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    ),
                  ).animate().scale(delay: 250.ms),
                  const SizedBox(height: 10),
                  _buildGlassFAB(
                    heroTag: 'settings',
                    icon: Icons.settings_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ).animate().scale(delay: 300.ms),
                  const SizedBox(height: 10),
                  _buildGlassFAB(
                    heroTag: 'logout',
                    icon: Icons.logout_rounded,
                    onPressed: _logout,
                  ).animate().scale(delay: 400.ms),
                  if (isActive) ...[
                    const SizedBox(height: 10),
                    _buildGlassFAB(
                      heroTag: 'chat',
                      icon: Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                      iconColor: Colors.white,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                    ).animate().scale(delay: 100.ms),
                    const SizedBox(height: 10),
                    _buildGlassFAB(
                      heroTag: 'sos',
                      icon: Icons.emergency_rounded,
                      color: AppColors.error,
                      iconColor: Colors.white,
                      onPressed: () => _sendSos(ride!['id'] as int),
                    ).animate().scale(delay: 200.ms),
                  ],
                ],
              ),
            ),
          ),

          // ── Active ride card ──────────────────────────────────────
          if (ride != null)
            Positioned(
              top: 112,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.medium,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppGradients.serviceType(ride['service_type'] ?? 'single'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        serviceTypeIcon(ride['service_type'] ?? 'single'),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isActive ? 'Ride ${status!.toUpperCase()}' : 'Ride $status',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    boxShadow: AppShadows.glow(AppColors.success),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₦${ride['estimated_fare']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom panel ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GlassmorphicContainer(
              width: MediaQuery.of(context).size.width,
              height: isActive ? 200 : 350,
              borderRadius: 28,
              blur: 20,
              alignment: Alignment.bottomCenter,
              border: 1,
              linearGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.8),
                ],
                stops: const [0.1, 1],
              ),
              borderGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // ── Service type pills ─────────────────────────────
                    if (!isActive)
                      SizedBox(
                        height: 50,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildServicePill('single', selectedType),
                            _buildServicePill('interstate', selectedType),
                            _buildServicePill('haulage', selectedType),
                            _buildServicePill('dispatch', selectedType),
                          ],
                        ),
                      ),

                    // ── Service-specific fields ─────────────────────────
                    if (!isActive) _buildServiceFields(selectedType),

                    const SizedBox(height: 16),

                    // ── Book button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppGradients.serviceType(selectedType),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.glow(stColor),
                        ),
                        child: ElevatedButton(
                          onPressed: (isActive || _locating || rideState.loading)
                              ? null
                              : _showCategorySelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white.withOpacity(0.6),
                            elevation: 0,
                            padding: const EdgeInsets.all(18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: rideState.loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(serviceTypeIcon(selectedType), size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      ride != null
                                          ? 'Ride $status'
                                          : 'Book ${serviceTypeLabel(selectedType)}',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().slideY(begin: 1.0, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Widget _buildServicePill(String type, String selectedType) {
    final isSelected = type == selectedType;
    final color = serviceTypeColor(type);

    return GestureDetector(
      onTap: () {
        ref.read(rideProvider.notifier).setServiceType(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.serviceType(type) : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? AppShadows.glow(color) : null,
        ),
        child: Row(
          children: [
            Icon(
              serviceTypeIcon(type),
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              serviceTypeLabel(type),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassFAB({
    required String heroTag,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    Color? iconColor,
  }) {
    return FloatingActionButton(
      mini: true,
      heroTag: heroTag,
      elevation: 4,
      backgroundColor: color ?? Colors.white,
      onPressed: onPressed,
      child: Icon(icon, color: iconColor ?? Colors.grey.shade700, size: 20),
    );
  }
}
