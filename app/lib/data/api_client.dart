import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session.dart';

/// Base URL of the DPOS API.
/// - Android emulator reaches the host machine via 10.0.2.2.
/// - For Windows/desktop/web on the same machine, use http://localhost:3000.
/// Override with --dart-define=API_BASE_URL=...
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api/v1',
);

class ApiClient {
  ApiClient(String? token)
      : _dio = Dio(BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ));

  final Dio _dio;

  static Future<Map<String, dynamic>> loginPin(String merchantId, String pin) async {
    final dio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
    final res = await dio.post('/auth/login', data: {'merchantId': merchantId, 'pin': pin});
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> loginOwner(String email, String password) async {
    final dio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
    final res = await dio.post('/auth/login', data: {'email': email, 'password': password});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCatalog(String outletId) async {
    final res = await _dio.get('/catalog', queryParameters: {'outletId': outletId});
    return res.data as Map<String, dynamic>;
  }

  /// Returns the created/replayed order JSON. Throws DioException on network/HTTP failure.
  Future<Map<String, dynamic>> submitOrder(Map<String, dynamic> payload) async {
    final res = await _dio.post('/orders', data: payload);
    return res.data as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionProvider);
  return ApiClient(session?.token);
});
