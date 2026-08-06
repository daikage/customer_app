import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

class RideState {
  final Map<String, dynamic>? ride;
  final List<Map<String, dynamic>> availableRides;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> messages;
  final bool loading;
  final String? error;

  const RideState({
    this.ride,
    this.availableRides = const [],
    this.categories = const [],
    this.messages = const [],
    this.loading = false,
    this.error,
  });

  RideState copyWith({
    Map<String, dynamic>? ride,
    List<Map<String, dynamic>>? availableRides,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? messages,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return RideState(
      ride: ride ?? this.ride,
      availableRides: availableRides ?? this.availableRides,
      categories: categories ?? this.categories,
      messages: messages ?? this.messages,
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
    int? categoryId,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await ApiService.instance.dio.post('/rides', data: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'pickup_address': pickupAddress,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'dropoff_address': dropoffAddress,
        'distance_km': distanceKm,
        if (categoryId != null) 'ride_category_id': categoryId,
      });
      final ride = (response.data['ride'] as Map).cast<String, dynamic>();
      state = state.copyWith(ride: ride, loading: false);
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

  Future<void> fetchCategories() async {
    try {
      final response = await ApiService.instance.dio.get('/ride-categories');
      final cats = (response.data['categories'] as List)
          .map((c) => (c as Map).cast<String, dynamic>())
          .toList();
      state = state.copyWith(categories: cats);
    } on Exception {
      // Ignore
    }
  }

  Future<void> rateRide(int rideId, int stars, String comment) async {
    try {
      await ApiService.instance.dio.post('/rides/$rideId/rate', data: {
        'stars': stars,
        'comment': comment,
      });
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> sendSos(int rideId, double lat, double lng) async {
    try {
      await ApiService.instance.dio.post('/rides/$rideId/sos', data: {
        'lat': lat,
        'lng': lng,
      });
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> fetchMessages(int rideId) async {
    try {
      final response = await ApiService.instance.dio.get('/rides/$rideId/messages');
      final msgs = (response.data['messages'] as List)
          .map((m) => (m as Map).cast<String, dynamic>())
          .toList();
      state = state.copyWith(messages: msgs);
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
    }
  }

  Future<void> sendMessage(int rideId, String body) async {
    try {
      final response = await ApiService.instance.dio.post('/rides/$rideId/messages', data: {
        'body': body,
      });
      final newMsg = (response.data['message'] as Map).cast<String, dynamic>();
      state = state.copyWith(messages: [...state.messages, newMsg]);
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  void appendMessage(Map<String, dynamic> message) {
    if (!state.messages.any((m) => m['id'] == message['id'])) {
      state = state.copyWith(messages: [...state.messages, message]);
    }
  }

  void clear() => state = const RideState();
}

final rideProvider =
    StateNotifierProvider<RideNotifier, RideState>((ref) => RideNotifier());
