import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class WalletState {
  final Map<String, dynamic>? wallet;
  final List<Map<String, dynamic>> transactions;
  final bool loading;
  final String? error;

  const WalletState({
    this.wallet,
    this.transactions = const [],
    this.loading = false,
    this.error,
  });

  WalletState copyWith({
    Map<String, dynamic>? wallet,
    List<Map<String, dynamic>>? transactions,
    bool? loading,
    String? error,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  Future<void> fetchWalletAndTransactions() async {
    state = state.copyWith(loading: true);
    try {
      final walletRes = await ApiService.instance.dio.get('/customer/wallet');
      final txnRes =
          await ApiService.instance.dio.get('/customer/transactions');

      final wallet =
          (walletRes.data['wallet'] as Map).cast<String, dynamic>();
      final txnList = (txnRes.data['transactions'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      state = state.copyWith(
        wallet: wallet,
        transactions: txnList,
        loading: false,
        error: null,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        loading: false,
        error: ApiService.friendlyError(e),
      );
    }
  }

  Future<String> topupWallet(double amount, String gateway) async {
    try {
      final res = await ApiService.instance.dio.post(
        '/payment/topup',
        data: {
          'amount': amount,
          'gateway': gateway,
        },
      );
      return res.data['authorization_url'] as String;
    } on Exception catch (e) {
      throw Exception(ApiService.friendlyError(e));
    }
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>(
        (ref) => WalletNotifier());
