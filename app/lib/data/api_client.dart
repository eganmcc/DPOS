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
  ApiClient(String? token, {void Function()? onUnauthorized})
      : _dio = Dio(BaseOptions(
          baseUrl: kApiBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        )) {
    // A 401 on an authenticated call means the token expired or was revoked.
    // Hand it to [onUnauthorized] (which clears the session and routes to
    // login) so an expired session never masquerades as a connection error.
    // Login endpoints use their own Dio, so a wrong-PIN 401 never lands here.
    if (onUnauthorized != null) {
      _dio.interceptors.add(InterceptorsWrapper(
        onError: (e, handler) {
          if (e.response?.statusCode == 401) onUnauthorized();
          handler.next(e);
        },
      ));
    }
  }

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

  /// DEMO: public directory of demo merchants → outlets (+ cashier PIN) for the
  /// login-screen dropdowns.
  static Future<List<Map<String, dynamic>>> demoDirectory() async {
    final dio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
    final res = await dio.get('/demo/directory');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getCatalog(String outletId) async {
    final res = await _dio.get('/catalog', queryParameters: {'outletId': outletId});
    return res.data as Map<String, dynamic>;
  }

  /// Backend build info: {name, version}. Public endpoint.
  Future<Map<String, dynamic>> getVersion() async {
    final res = await _dio.get('/version');
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

  /// Open bills (AWAITING_PAYMENT) for an outlet, newest first.
  Future<List<Map<String, dynamic>>> getOpenOrders(String outletId) async {
    final res = await _dio.get('/orders/open', queryParameters: {'outletId': outletId});
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Online-delivery orders for an outlet (NEW first). F&B online-order queue.
  Future<List<Map<String, dynamic>>> getOnlineOrders(String outletId) async {
    final res = await _dio.get('/online-orders', queryParameters: {'outletId': outletId});
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  /// Cashier acknowledges a new online order (NEW → ACCEPTED).
  Future<Map<String, dynamic>> acceptOnlineOrder(String orderId) async {
    final res = await _dio.post('/online-orders/$orderId/accept');
    return res.data as Map<String, dynamic>;
  }

  /// Mark an online order fulfilled (→ COMPLETED) — moves it out of the queue to history.
  Future<Map<String, dynamic>> completeOnlineOrder(String orderId) async {
    final res = await _dio.post('/online-orders/$orderId/complete');
    return res.data as Map<String, dynamic>;
  }

  /// DEMO: ask the server to fabricate + ingest a random online order for the outlet.
  Future<Map<String, dynamic>> simulateOnlineOrder(String outletId) async {
    final res = await _dio.post('/online-orders/simulate', data: {'outletId': outletId});
    return res.data as Map<String, dynamic>;
  }

  /// Edit an open bill (replace its lines/discount/table) while it is AWAITING_PAYMENT.
  Future<Map<String, dynamic>> reviseOrder(String orderId, Map<String, dynamic> payload) async {
    final res = await _dio.post('/orders/$orderId/revise', data: payload);
    return res.data as Map<String, dynamic>;
  }

  /// Settle an open bill: attach payment and complete it. Returns the settled order.
  /// [clientSettleId] is the idempotency key.
  Future<Map<String, dynamic>> settleOrder(
    String orderId, {
    required String clientSettleId,
    required String method, // CASH | QRIS_SIMULATED
    int? tendered,
  }) async {
    final res = await _dio.post('/orders/$orderId/settle', data: {
      'clientSettleId': clientSettleId,
      'payment': {'method': method, if (tendered != null) 'tendered': tendered},
    });
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
  // Capture the notifiers (app-lifetime singletons) so the interceptor callback
  // stays valid even after this provider rebuilds on logout.
  final sessionNotifier = ref.read(sessionProvider.notifier);
  final expired = ref.read(sessionExpiredProvider.notifier);
  return ApiClient(
    session?.token,
    onUnauthorized: session == null
        ? null
        : () {
            expired.state = true;
            sessionNotifier.logout();
          },
  );
});
