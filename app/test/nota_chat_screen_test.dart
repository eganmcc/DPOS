import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dpos/core/theme.dart';
import 'package:dpos/features/nota_chat/nota_chat_screen.dart';
import 'package:dpos/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The nota chat end to end, minus the camera and the network (specs/009): send a photo, read the
/// reading, answer "is anything wrong?", and see the open transaction appear.
void main() {
  // A 1×1 PNG: enough for Image.memory to decode.
  final png = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='));

  /// Slip 2237 as the reader returns it.
  Map<String, dynamic> slip2237() => {
        'notaNumber': '2237',
        'notaDate': '2026-08-02',
        'customerName': 'Edward',
        'items': [
          {'rawText': '1 M BESAR', 'qty': 1, 'unitPrice': 130000, 'lineTotal': 130000},
          {'rawText': 'A/J FREE', 'qty': null, 'unitPrice': null, 'lineTotal': null},
        ],
        'total': 130000,
        'unclear': <String>[],
        'confidence': 95,
        'model': 'claude-opus-5',
        'latencyMs': 3700,
      };

  late List<Map<String, dynamic>> posted;
  late Object? Function(Map<String, dynamic> payload) respond; // a Map, or a DioException to throw
  late Map<String, dynamic> readingJson;
  late List<(String, int)> paid;
  late List<String> viewed;

  DioException refused(int status, Map<String, dynamic> body) => DioException(
        requestOptions: RequestOptions(path: '/orders'),
        response: Response(requestOptions: RequestOptions(path: '/orders'), statusCode: status, data: body),
        type: DioExceptionType.badResponse,
      );

  Future<void> pump(WidgetTester tester) async {
    posted = [];
    paid = [];
    viewed = [];
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NotaChatBody(
          outletId: 'outlet-1',
          deviceId: 'device-1',
          openAmountVariantId: 'v-open',
          pickPhoto: (_) async => png,
          readNota: (_) async => readingJson,
          createSale: (payload) async {
            posted.add(payload);
            final r = respond(payload);
            if (r is DioException) throw r;
            return r as Map<String, dynamic>;
          },
          onPay: (id, total) => paid.add((id, total)),
          onViewOrder: viewed.add,
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> sendPhoto(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('chat-camera')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    readingJson = slip2237();
    respond = (_) => {'id': 'order-1', 'grandTotal': 130000, 'status': 'AWAITING_PAYMENT'};
  });

  testWidgets('a photo is read back line by line, and the chat asks whether anything is wrong',
      (tester) async {
    await pump(tester);
    await sendPhoto(tester);

    expect(find.text('Nota #2237  ·  02-08-2026  ·  Edward'), findsOneWidget);
    expect(find.text('1 M BESAR'), findsOneWidget);
    expect(find.text('A/J FREE'), findsOneWidget);
    expect(find.text('tidak dihitung'), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('chat-charge-total'))).data, 'Rp 130.000');
    // The cashier sees exactly what will be kept as the note before confirming.
    expect(find.byKey(const ValueKey('chat-note-preview')), findsOneWidget);
    expect(find.text('Dicatat sebagai catatan transaksi:'), findsOneWidget);
    expect(find.text('Apakah ada yang perlu diperbaiki?'), findsOneWidget);
    expect(posted, isEmpty, reason: 'nothing is recorded before the cashier confirms');
  });

  testWidgets('"Tidak" records it as an open transaction, and "Bayar sekarang" goes to settle',
      (tester) async {
    await pump(tester);
    await sendPhoto(tester);
    await tester.tap(find.byKey(const ValueKey('chat-fix-no')));
    await tester.pumpAndSettle();

    expect(posted, hasLength(1));
    final body = posted.single;
    expect(body.containsKey('payment'), false, reason: 'no payment = open transaction');
    expect(body['notaNumber'], '2237');
    expect(body['customerName'], 'Edward');
    expect(body['lines'], [
      {'variantId': 'v-open', 'qty': 1, 'amount': 130000, 'label': '1 M BESAR'},
    ]);
    // What was written but not charged goes with it, as the transaction note.
    expect(body['note'], 'Tidak dihitung: A/J FREE');
    expect(find.byKey(const ValueKey('chat-created')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-pay')));
    expect(paid, [('order-1', 130000)]);
  });

  testWidgets('"Ya" records nothing and says corrections are not available yet', (tester) async {
    await pump(tester);
    await sendPhoto(tester);
    await tester.tap(find.byKey(const ValueKey('chat-fix-yes')));
    await tester.pumpAndSettle();

    expect(posted, isEmpty);
    expect(find.textContaining('Perbaikan belum tersedia'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-fix-no')), findsNothing);
  });

  testWidgets('a nota already recorded is not created twice, and links to the existing one',
      (tester) async {
    respond = (_) => refused(409, {'code': 'NOTA_ALREADY_RECORDED', 'orderId': 'order-9'});
    await pump(tester);
    await sendPhoto(tester);
    await tester.tap(find.byKey(const ValueKey('chat-fix-no')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-duplicate')), findsOneWidget);
    expect(find.textContaining('Nota #2237 sudah tercatat'), findsOneWidget);
    await tester.tap(find.text('Lihat transaksi'));
    expect(viewed, ['order-9']);
  });

  testWidgets('a failed create keeps the question open, and a retry is the same transaction',
      (tester) async {
    var attempts = 0;
    respond = (_) => ++attempts == 1
        ? refused(500, {'message': 'boom'})
        : {'id': 'order-1', 'grandTotal': 130000};
    await pump(tester);
    await sendPhoto(tester);

    await tester.tap(find.byKey(const ValueKey('chat-fix-no')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Transaksi belum dibuat'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-fix-no')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-fix-no')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-created')), findsOneWidget);
    // Same reading, same idempotency key: the server can never record it twice.
    expect(posted[0]['clientOrderId'], posted[1]['clientOrderId']);
  });

  testWidgets('with no readable price there is nothing to confirm', (tester) async {
    readingJson = {
      ...slip2237(),
      'items': [
        {'rawText': '1 M BESAR', 'lineTotal': null},
      ],
      'total': null,
    };
    await pump(tester);
    await sendPhoto(tester);

    expect(find.textContaining('Tidak ada harga yang terbaca'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-fix-no')), findsNothing);
  });
}
