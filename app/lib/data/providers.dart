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
