import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

/// A YYYY-MM-DD date range used to key the reporting providers.
typedef DateRange = ({String from, String to});

/// Owner/manager sales summary (GET /admin/dashboard) over a date range.
final dashboardProvider =
    FutureProvider.autoDispose.family<DashboardSummary, DateRange>((ref, range) async {
  final api = ref.watch(apiClientProvider);
  return DashboardSummary.fromJson(await api.getDashboard(from: range.from, to: range.to));
});

/// Owner/manager attendance rows over a date range (GET /admin/attendance).
final adminAttendanceProvider =
    FutureProvider.autoDispose.family<List<AttendanceRow>, DateRange>((ref, range) async {
  final api = ref.watch(apiClientProvider);
  final rows = await api.getAdminAttendance(from: range.from, to: range.to);
  return rows.map(AttendanceRow.fromJson).toList();
});

/// The caller's own current attendance state (null = clocked out).
final myAttendanceProvider = FutureProvider.autoDispose<AttendanceRecord?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final j = await api.getMyAttendance();
  return j == null ? null : AttendanceRecord.fromJson(j);
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

/// This app's own version, read from the bundle (e.g. "0.1.0+2008"). Not hardcoded.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// Backend version, queried from GET /version. Not hardcoded.
final serverVersionProvider = FutureProvider.autoDispose<String>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getVersion();
  return json['version']?.toString() ?? 'unknown';
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
