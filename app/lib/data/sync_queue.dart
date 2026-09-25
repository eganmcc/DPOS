import 'dart:convert';
import 'package:dio/dio.dart';
import 'db/database.dart';
import 'api_client.dart';
import 'models.dart';

/// What a background drainer needs from the queue: replay what is waiting, and say how much is.
///
/// Exists so `SyncFlusher` can be tested without a real database or HTTP client — the flusher's
/// job is the *when* (connectivity, resume, timer, no overlapping passes), which is exactly the
/// part that needs a test and the part a live `SyncQueue` makes impossible to write.
abstract class OrderQueue {
  Future<int> flush();
  Future<int> pendingCount();
}

/// Offline-first submit path (Constitution V):
///  - every order is enqueued locally with its client-generated UUID,
///  - a submit is attempted immediately; on network failure the row stays 'pending',
///  - flush() retries pending rows; the server dedups on (merchantId, clientOrderId),
///    so retries never double-post.
class SyncQueue implements OrderQueue {
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
      // The server answered and refused → surface it and never replay it (see markRejected).
      if (e.response != null) {
        await _db.markRejected(clientOrderId, 'HTTP ${e.response?.statusCode}');
        rethrow;
      }
      // Never reached the server → stays queued for the flusher.
      await _db.markFailed(clientOrderId, 'offline');
      return null;
    }
  }

  /// Retry every queued order. Returns how many synced this pass.
  ///
  /// Safe to call as often as you like: each order replays under its original `clientOrderId`,
  /// which the server dedups (Constitution V), so a flush racing a live submit cannot double-charge.
  @override
  Future<int> flush() async {
    final pending = await _db.pendingToSync();
    var synced = 0;
    for (final row in pending) {
      try {
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        final json = await _api.submitOrder(payload);
        await _db.markSynced(row.clientOrderId, json['id'] as String, jsonEncode(json));
        synced++;
      } on DioException catch (e) {
        if (e.response != null) {
          // The server refused it — retrying would refuse for ever. Stop, and keep the reason.
          await _db.markRejected(row.clientOrderId, 'HTTP ${e.response?.statusCode}');
        }
        // No response: still offline / transient — leave pending, try again next time.
      }
    }
    return synced;
  }

  @override
  Future<int> pendingCount() async => (await _db.pendingToSync()).length;
}
