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

  Future<void> markFailed(String clientOrderId, String error) =>
      (update(pendingOrders)..where((o) => o.clientOrderId.equals(clientOrderId))).write(
        PendingOrdersCompanion(lastError: Value(error)),
      );

  Future<List<PendingOrder>> pendingToSync() =>
      (select(pendingOrders)..where((o) => o.status.equals('pending'))).get();
}

QueryExecutor _open() => driftDatabase(name: 'dpos');
