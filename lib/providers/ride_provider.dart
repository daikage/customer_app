import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

class RideState {
  final Map<String, dynamic>? ride;
  final List<Map<String, dynamic>> availableRides;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? estimate;
  final String selectedServiceType;
  final bool loading;
  final String? error;

  const RideState({
    this.ride,
    this.availableRides = const [],
    this.categories = const [],
    this.messages = const [],
    this.history = const [],
    this.estimate,
    this.selectedServiceType = 'single',
    this.loading = false,
    this.error,
  });

  RideState copyWith({
    Map<String, dynamic>? ride,
    List<Map<String, dynamic>>? availableRides,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? estimate,
    String? selectedServiceType,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearRide = false,
    bool clearEstimate = false,
  }) {
    return RideState(
      ride: clearRide ? null : (ride ?? this.ride),
      availableRides: availableRides ?? this.availableRides,
      categories: categories ?? this.categories,
      messages: messages ?? this.messages,
      history: history ?? this.history,
      estimate: clearEstimate ? null : (estimate ?? this.estimate),
      selectedServiceType: selectedServiceType ?? this.selectedServiceType,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RideNotifier extends StateNotifier<RideState> {
  RideNotifier() : super(const RideState());

  void setServiceType(String type) {
    state = state.copyWith(selectedServiceType: type, categories: const []);
    fetchCategories(serviceType: type);
  }

  Future<void> requestRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required double distanceKm,
    int? categoryId,
    String serviceType = 'single',
    Map<String, dynamic>? serviceMeta,
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
        'service_type': serviceType,
        if (categoryId != null) 'ride_category_id': categoryId,
        if (serviceMeta != null) 'service_meta': serviceMeta,
      });
      final ride = (response.data['ride'] as Map).cast<String, dynamic>();
      state = state.copyWith(ride: ride, loading: false);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> cancelRide(int rideId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await ApiService.instance.dio.post('/rides/$rideId/cancel');
      state = state.copyWith(loading: false, clearRide: true);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> estimateFare({
    required double distanceKm,
    String serviceType = 'single',
    int? categoryId,
  }) async {
    try {
      final response = await ApiService.instance.dio.post('/rides/estimate', data: {
        'distance_km': distanceKm,
        'service_type': serviceType,
        if (categoryId != null) 'ride_category_id': categoryId,
      });
      final data = (response.data as Map).cast<String, dynamic>();
      state = state.copyWith(estimate: data);
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
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
        state = state.copyWith(clearRide: true);
        return;
      }
      state = state.copyWith(ride: (raw as Map).cast<String, dynamic>());
    } on Exception {
      // Keep the current state if the request fails.
    }
  }

  Future<void> fetchAvailable({String? serviceType}) async {
    if (state.loading) return;
    try {
      final params = <String, dynamic>{};
      if (serviceType != null) params['service_type'] = serviceType;
      final response = await ApiService.instance.dio.get('/rides/available',
          queryParameters: params.isNotEmpty ? params : null);
      final rides = (response.data['rides'] as List)
          .map((r) => (r as Map).cast<String, dynamic>())
          .toList();
      state = state.copyWith(availableRides: rides);
    } on Exception {
      // Keep the current state if the request fails.
    }
  }

  Future<void> fetchCategories({String? serviceType}) async {
    try {
      final params = <String, dynamic>{};
      if (serviceType != null) params['service_type'] = serviceType;
      final response = await ApiService.instance.dio.get('/ride-categories',
          queryParameters: params.isNotEmpty ? params : null);
      final cats = (response.data['categories'] as List)
          .map((c) => (c as Map).cast<String, dynamic>())
          .toList();
      state = state.copyWith(categories: cats);
    } on Exception {
      // Ignore
    }
  }

  Future<void> fetchHistory() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await ApiService.instance.dio.get('/rides/history');
      final rides = (response.data['rides']['data'] as List)
          .map((r) => (r as Map).cast<String, dynamic>())
          .toList();
      state = state.copyWith(history: rides, loading: false);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: ApiService.friendlyError(e));
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

