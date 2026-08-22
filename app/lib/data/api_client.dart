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

  /// Transaction history for an outlet, newest first (server-scoped to the merchant).
  Future<List<Map<String, dynamic>>> getOrders(String outletId, {String? from, String? to}) async {
    final res = await _dio.get('/orders', queryParameters: {
      'outletId': outletId,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// One transaction with its lines, payments and voids.
  Future<Map<String, dynamic>> getOrder(String orderId) async {
    final res = await _dio.get('/orders/$orderId');
    return res.data as Map<String, dynamic>;
  }

  /// Full-void a completed sale. OWNER only — a cashier's token comes back 403.
  /// [clientVoidId] is the idempotency key: retrying with the same value is a no-op server-side.
  Future<Map<String, dynamic>> voidOrder(
    String orderId, {
    required String clientVoidId,
    String? reason,
  }) async {
    final res = await _dio.post('/orders/$orderId/void', data: {
      'clientVoidId': clientVoidId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionProvider);
  return ApiClient(session?.token);
});
