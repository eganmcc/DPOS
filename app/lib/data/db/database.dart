import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Cached catalog per outlet so the POS can display products offline.
class CatalogCache extends Table {
  TextColumn get outletId => text()();
  TextColumn get payload => text()(); // catalog JSON
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {outletId};
}

/// Offline order queue. Each row carries a client-generated UUID (clientOrderId) so a retried
/// submit is idempotent on the server (Constitution V). Financial rows are append-based here too.
class PendingOrders extends Table {
  TextColumn get clientOrderId => text()(); // client UUID = idempotency key
  TextColumn get outletId => text()();
  TextColumn get payload => text()(); // full submit JSON
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|synced|failed
  TextColumn get serverOrderId => text().nullable()();
  TextColumn get resultPayload => text().nullable()(); // server OrderResult JSON when synced
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientOrderId};
}

@DriftDatabase(tables: [CatalogCache, PendingOrders])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 1;

  Future<void> upsertCatalog(String outletId, String payload) => into(catalogCache).insertOnConflictUpdate(
        CatalogCacheCompanion.insert(outletId: outletId, payload: payload, updatedAt: DateTime.now()),
      );

  Future<CatalogCacheData?> getCatalog(String outletId) =>
      (select(catalogCache)..where((c) => c.outletId.equals(outletId))).getSingleOrNull();

  Future<void> enqueueOrder(String clientOrderId, String outletId, String payload) =>
      into(pendingOrders).insertOnConflictUpdate(
        PendingOrdersCompanion.insert(
          clientOrderId: clientOrderId,
          outletId: outletId,
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );

  Future<void> markSynced(String clientOrderId, String serverOrderId, String resultPayload) =>
      (update(pendingOrders)..where((o) => o.clientOrderId.equals(clientOrderId))).write(
        PendingOrdersCompanion(
          status: const Value('synced'),
          serverOrderId: Value(serverOrderId),
          resultPayload: Value(resultPayload),
        ),
      );

  /// Send failed but the order is still OURS to retry — it never reached the server.
  /// Stays `pending`, so the flusher picks it up on the next connection.
  Future<void> markFailed(String clientOrderId, String error) =>
      (update(pendingOrders)..where((o) => o.clientOrderId.equals(clientOrderId))).write(
        PendingOrdersCompanion(lastError: Value(error)),
      );

  /// The server ANSWERED and refused it. Never retried: the cashier was told it failed, and a
  /// silent replay minutes later (after a restock, say) would create a sale nobody rang up.
  /// Re-ringing it is the cashier's decision, and that makes a new `clientOrderId`.
  Future<void> markRejected(String clientOrderId, String error) =>
      (update(pendingOrders)..where((o) => o.clientOrderId.equals(clientOrderId))).write(
        PendingOrdersCompanion(status: const Value('rejected'), lastError: Value(error)),
      );

  Future<List<PendingOrder>> pendingToSync() =>
      (select(pendingOrders)..where((o) => o.status.equals('pending'))).get();

  Future<PendingOrder?> orderByClientId(String clientOrderId) =>
      (select(pendingOrders)..where((o) => o.clientOrderId.equals(clientOrderId)))
          .getSingleOrNull();

  /// Whether a sale was captured on this device: synced, or queued and still going to sync.
  ///
  /// `SyncQueue.submit` enqueues BEFORE it posts, so a row exists even if the app died mid-send —
  /// and `flush` will replay it under the same `clientOrderId`, which the server dedups. A row the
  /// server refused (`lastError` "HTTP 4xx") was never recorded, so it does not count.
  Future<bool> isOrderCaptured(String clientOrderId) async {
    final row = await orderByClientId(clientOrderId);
    if (row == null) return false;
    if (row.status == 'synced') return true;
    return !(row.lastError?.startsWith('HTTP') ?? false);
  }
}

QueryExecutor _open() => driftDatabase(name: 'dpos');
