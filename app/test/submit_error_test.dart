import 'package:dio/dio.dart';
import 'package:dpos/core/submit_error.dart';
import 'package:dpos/l10n/app_localizations_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a cashier reads when a sale is not saved. Until 2026-09-21 it was "Gagal masuk (cek
/// koneksi)" for every refusal — a sign-in message — which is how an out-of-stock order passed
/// for a dead network.
void main() {
  final t = AppLocalizationsId();
  final req = RequestOptions(path: '/orders');

  DioException refused(int status, Object? data) => DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: status, data: data),
        type: DioExceptionType.badResponse,
      );

  test('never reached the server: says so, and only then mentions the connection', () {
    final e = DioException(requestOptions: req, type: DioExceptionType.connectionError);
    expect(describeSubmitError(t, e), 'Tidak bisa terhubung ke server — cek koneksi.');
  });

  test('refused for stock: the item, in Indonesian, and that nothing was saved', () {
    final e = refused(400, {'message': 'Insufficient stock for Mie Goreng', 'statusCode': 400});
    expect(describeSubmitError(t, e), 'Stok Mie Goreng tidak cukup — pesanan tidak disimpan.');
  });

  test("any other refusal: the server's own words", () {
    final e = refused(400, {'message': 'One or more variants are invalid for this merchant'});
    expect(describeSubmitError(t, e), 'One or more variants are invalid for this merchant');
  });

  test('a validation list: its first message', () {
    final e = refused(400, {
      'message': ['lines must contain at least 1 elements', 'outletId must be a UUID'],
    });
    expect(describeSubmitError(t, e), 'lines must contain at least 1 elements');
  });

  test('no message at all: the status code', () {
    expect(describeSubmitError(t, refused(502, '<html>Bad Gateway</html>')),
        'Gagal menyimpan pesanan (kode 502).');
  });

  test('never the sign-in message', () {
    for (final e in [
      refused(400, {'message': 'Insufficient stock for X'}),
      refused(500, null),
      DioException(requestOptions: req, type: DioExceptionType.connectionTimeout),
    ]) {
      expect(describeSubmitError(t, e), isNot(contains('Gagal masuk')));
    }
  });
}
