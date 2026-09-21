import 'package:dio/dio.dart';

import '../l10n/app_localizations.dart';

/// What to tell the cashier when a sale could not be saved.
///
/// Until 2026-09-21 every refused sale said "Gagal masuk (cek koneksi)" — a *sign-in* message —
/// whatever the server actually answered, so an out-of-stock order looked like a dead network.
/// The rule now: if the request never reached the server, say so; if the server refused, say why,
/// in its words (the one refusal a till hits daily, stock, in Indonesian); otherwise give the code.
String describeSubmitError(AppLocalizations t, DioException e) {
  final res = e.response;
  if (res == null) return t.errorConnection;

  final data = res.data;
  String? message;
  if (data is Map) {
    final m = data['message'];
    if (m is String && m.trim().isNotEmpty) {
      message = m.trim();
    } else if (m is List && m.isNotEmpty) {
      // class-validator returns a list; the first one is enough to act on.
      message = m.first.toString();
    }
  }
  if (message != null) {
    final stock = RegExp(r'^Insufficient stock for (.+)$').firstMatch(message);
    if (stock != null) return t.errorStockShort(stock.group(1)!);
    return message;
  }
  return t.errorSaveFailed(res.statusCode ?? 0);
}
