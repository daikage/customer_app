import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

class RideState {
  final Map<String, dynamic>? ride;
  final List<Map<String, dynamic>> availableRides;
  final bool loading;
  final String? error;

  const RideState({
    this.ride,
    this.availableRides = const [],
    this.loading = false,
    this.error,
  });

  RideState copyWith({
    Map<String, dynamic>? ride,
    List<Map<String, dynamic>>? availableRides,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return RideState(
      ride: ride ?? this.ride,
      availableRides: availableRides ?? this.availableRides,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RideNotifier extends StateNotifier<RideState> {
  RideNotifier() : super(const RideState());

  Future<void> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required double distanceKm,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await ApiService.instance.dio.post('/rides/request', data: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup_address': pickupAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'dropoff_address': dropoffAddress,
        'distance_km': distanceKm,
      });
      final ride = (response.data['ride'] as Map).cast<String, dynamic>();
      state = RideState(ride: ride);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> acceptRide(int rideId) async {
    try {
      final response = await ApiService.instance.dio.post('/rides/$rideId/accept');
      final ride = (response.data['ride'] as Map).cast<String, dynamic>();
      state = state.copyWith(ride: ride, availableRides: const []);
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> updateStatus(int rideId, String status) async {
    try {
      final response = await ApiService.instance
          .dio.post('/rides/$rideId/status', data: {'status': status});
      final ride = (response.data['ride'] as Map).cast<String, dynamic>();
      state = state.copyWith(ride: ride);
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  /// Fire-and-forget driver location update for a ride.
  Future<void> updateLocation(int rideId, double lat, double lng) async {
    try {
      await ApiService.instance
          .dio.post('/rides/$rideId/location', data: {'lat': lat, 'lng': lng});
    } on Exception {
      // Location updates are best-effort; ignore transient failures.
    }
  }

  Future<void> fetchActive() async {
    try {
      final response = await ApiService.instance.dio.get('/rides/active');
      final raw = response.data['ride'];
      if (raw == null) {
        state = const RideState();
        return;
      }
      state = RideState(ride: (raw as Map).cast<String, dynamic>());
    } on Exception {
      // Keep the current state if the request fails.
    }
  }

  Future<void> fetchAvailable() async {
    if (state.loading) return;
    try {
      final response = await ApiService.instance.dio.get('/rides/available');
      final rides = (response.data['rides'] as List)
          .map((r) => (r as Map).cast<String, dynamic>())
          .toList();
      state = state.copyWith(availableRides: rides);
    } on Exception {
      // Keep the current state if the request fails.
    }
  }

  void clear() => state = const RideState();
}

final rideProvider =
    StateNotifierProvider<RideNotifier, RideState>((ref) => RideNotifier());
