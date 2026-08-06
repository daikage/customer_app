import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around Dio that stores the Sanctum bearer token and injects
/// it into every request automatically.
class ApiService {
  // 10.0.2.2 maps to the host machine when running on the Android emulator.
  // Replace this with your machine's LAN IP when testing on a physical device.
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  static final ApiService instance = ApiService._();

  static const _tokenKey = 'auth_token';

  late final Dio dio;

  ApiService._() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Extract a friendly, human-readable error message from a Dio error.
  static String friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        if (data['message'] != null) return data['message'].toString();
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Could not reach the server. Please try again.';
      }
      if (error.response?.statusCode == 401) {
        return 'Invalid credentials. Please try again.';
      }
      return error.message ?? 'Request failed.';
    }
    return 'Something went wrong. Please try again.';
  }
}
