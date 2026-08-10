import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class AuthState {
  final Map<String, dynamic>? user;
  final bool loading;
  final bool restoring;
  final String? error;

  const AuthState({
    this.user,
    this.loading = false,
    this.restoring = false,
    this.error,
  });

  bool get isLoggedIn => user != null;
  bool get isDriver => user?['role'] == 'driver';
  bool get isCustomer => user?['role'] == 'customer';

  AuthState copyWith({
    Map<String, dynamic>? user,
    bool? loading,
    bool? restoring,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      restoring: restoring ?? this.restoring,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(restoring: true)) {
    restore();
  }

  static const _userKey = 'auth_user';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      state = AuthState(user: (jsonDecode(raw) as Map).cast<String, dynamic>());
    } else {
      state = const AuthState();
    }
  }

  Future<void> login(String login, String password) async {
    state = state.copyWith(loading: true, error: null, clearError: true);
    try {
      final response = await ApiService.instance.dio.post('/login', data: {
        'login': login,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      final user = (data['user'] as Map).cast<String, dynamic>();
      await ApiService.instance.setToken(data['access_token'] as String);
      await _persistUser(user);
      state = AuthState(user: user);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(loading: true, error: null, clearError: true);
    try {
      final response = await ApiService.instance.dio.post('/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      });
      final data = response.data as Map<String, dynamic>;
      final user = (data['user'] as Map).cast<String, dynamic>();
      await ApiService.instance.setToken(data['access_token'] as String);
      await _persistUser(user);
      state = AuthState(user: user);
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> toggleAvailability() async {
    try {
      final response = await ApiService.instance.dio.post('/driver/availability');
      final user = {...?state.user};
      user['is_online'] = response.data['is_online'];
      await _persistUser(user);
      state = AuthState(user: user);
    } on Exception catch (e) {
      state = state.copyWith(error: ApiService.friendlyError(e));
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.instance.dio.post('/logout');
    } catch (_) {
      // A failed server call should not block a local logout.
    }
    await ApiService.instance.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    state = const AuthState();
  }

  Future<void> _persistUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> forgotPassword(String email) async {
    try {
      await ApiService.instance.dio.post('/forgot-password', data: {
        'email': email,
      });
    } on Exception catch (e) {
      throw Exception(ApiService.friendlyError(e));
    }
  }

  Future<void> resetPassword(String email, String otp, String password) async {
    try {
      await ApiService.instance.dio.post('/reset-password', data: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': password,
      });
    } on Exception catch (e) {
      throw Exception(ApiService.friendlyError(e));
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
