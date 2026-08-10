import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class PaymentState {
  final String? authorizationUrl;
  final String? reference;
  final String? status; // 'idle', 'initializing', 'pending', 'completed', 'failed'
  final bool loading;
  final String? error;

  const PaymentState({
    this.authorizationUrl,
    this.reference,
    this.status = 'idle',
    this.loading = false,
    this.error,
  });

  PaymentState copyWith({
    String? authorizationUrl,
    String? reference,
    String? status,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearUrl = false,
  }) {
    return PaymentState(
      authorizationUrl: clearUrl ? null : (authorizationUrl ?? this.authorizationUrl),
      reference: reference ?? this.reference,
      status: status ?? this.status,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier() : super(const PaymentState());

  /// Initialize a payment with Paystack or Flutterwave.
  Future<void> initialize({
    required int rideId,
    required double amount,
    String gateway = 'paystack',
  }) async {
    state = state.copyWith(loading: true, clearError: true, status: 'initializing');
    try {
      final response = await ApiService.instance.dio.post('/payment/initialize', data: {
        'ride_id': rideId,
        'amount': amount,
        'gateway': gateway,
      });
      final data = response.data as Map<String, dynamic>;
      state = state.copyWith(
        authorizationUrl: data['authorization_url'] as String?,
        reference: data['reference'] as String?,
        status: 'pending',
        loading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        loading: false,
        status: 'failed',
        error: ApiService.friendlyError(e),
      );
      rethrow;
    }
  }

  /// Verify payment after customer completes it.
  Future<void> verify({
    required String gateway,
    required String reference,
    String? transactionId,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = <String, dynamic>{'reference': reference};
      if (transactionId != null) data['transaction_id'] = transactionId;

      final response = await ApiService.instance.dio.post(
        '/payment/verify/$gateway',
        data: data,
      );
      final result = response.data as Map<String, dynamic>;
      final message = result['message'] as String? ?? '';

      state = state.copyWith(
        loading: false,
        status: message.contains('successful') ? 'completed' : 'failed',
      );
    } on Exception catch (e) {
      state = state.copyWith(
        loading: false,
        status: 'failed',
        error: ApiService.friendlyError(e),
      );
      rethrow;
    }
  }

  void reset() => state = const PaymentState();
}

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) => PaymentNotifier());
