import 'dart:convert';
import 'package:dio/dio.dart';
import 'db/database.dart';
import 'api_client.dart';
import 'models.dart';

/// Offline-first submit path (Constitution V):
///  - every order is enqueued locally with its client-generated UUID,
///  - a submit is attempted immediately; on network failure the row stays 'pending',
///  - flush() retries pending rows; the server dedups on (merchantId, clientOrderId),
///    so retries never double-post.
class SyncQueue {
  SyncQueue(this._db, this._api);

  final AppDatabase _db;
  final ApiClient _api;

  /// Returns the server OrderResult on success, or null when queued offline for later sync.
  Future<OrderResult?> submit(Map<String, dynamic> payload) async {
    final clientOrderId = payload['clientOrderId'] as String;
    final outletId = payload['outletId'] as String;
    await _db.enqueueOrder(clientOrderId, outletId, jsonEncode(payload));

    try {
      final json = await _api.submitOrder(payload);
      await _db.markSynced(clientOrderId, json['id'] as String, jsonEncode(json));
      return OrderResult.fromJson(json);
    } on DioException catch (e) {
      // Network/connectivity failure → keep queued; a real HTTP error (4xx) should surface.
      if (e.response != null) {
        await _db.markFailed(clientOrderId, 'HTTP ${e.response?.statusCode}');
        rethrow;
      }
      await _db.markFailed(clientOrderId, 'offline');
      return null;
    }
  }

  /// Retry all pending orders. Returns how many synced this pass.
  Future<int> flush() async {
    final pending = await _db.pendingToSync();
    var synced = 0;
    for (final row in pending) {
      try {
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        final json = await _api.submitOrder(payload);
        await _db.markSynced(row.clientOrderId, json['id'] as String, jsonEncode(json));
        synced++;
      } on DioException catch (_) {
        // still offline / transient — leave pending, try again next time
      }
    }
    return synced;
  }

  Future<int> pendingCount() async => (await _db.pendingToSync()).length;
}
