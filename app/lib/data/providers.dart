import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'db/database.dart';
import 'api_client.dart';
import 'models.dart';
import 'sync_queue.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncQueueProvider = Provider<SyncQueue>(
  (ref) => SyncQueue(ref.watch(appDatabaseProvider), ref.watch(apiClientProvider)),
);

/// Transaction history for an outlet (US3). Server-authoritative: history is always read from the
/// API, never from the local cache, so the derived effective status (COMPLETED/VOIDED/REFUNDED) is
/// the server's answer (Constitution I).
final transactionsProvider =
    FutureProvider.autoDispose.family<List<OrderResult>, String>((ref, outletId) async {
  final api = ref.watch(apiClientProvider);
  final rows = await api.getOrders(outletId);
  return rows.map(OrderResult.fromJson).toList();
});

/// One transaction, straight from the server (detail view + post-void refresh).
final transactionDetailProvider =
    FutureProvider.autoDispose.family<OrderResult, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  return OrderResult.fromJson(await api.getOrder(orderId));
});

/// Open bills (confirm-now-pay-later) for an outlet. Server-authoritative; invalidated
/// after confirming a new bill and after settling one.
final openBillsProvider =
    FutureProvider.autoDispose.family<List<OrderResult>, String>((ref, outletId) async {
  final api = ref.watch(apiClientProvider);
  final rows = await api.getOpenOrders(outletId);
  return rows.map(OrderResult.fromJson).toList();
});

/// Catalog for an outlet: fetch from API and cache; fall back to the cache when offline.
final catalogProvider = FutureProvider.family<Catalog, String>((ref, outletId) async {
  final api = ref.watch(apiClientProvider);
  final db = ref.watch(appDatabaseProvider);
  try {
    final json = await api.getCatalog(outletId);
    await db.upsertCatalog(outletId, jsonEncode(json));
    return Catalog.fromJson(json);
  } catch (_) {
    final cached = await db.getCatalog(outletId);
    if (cached != null) {
      return Catalog.fromJson(jsonDecode(cached.payload) as Map<String, dynamic>);
    }
    rethrow;
  }
});
