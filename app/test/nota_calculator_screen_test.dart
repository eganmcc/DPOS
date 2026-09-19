import 'package:dpos/core/theme.dart';
import 'package:dpos/features/calculator/nota_calculator_screen.dart';
import 'package:dpos/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The calculator screen end to end, minus the network: keys → list → total → payment dialog.
///
/// Drives [NotaCalculatorBody] directly, which takes its data as parameters, so no provider,
/// session, catalog or server is involved. Assertions read what the cashier sees.
void main() {
  late List<({List<int> amounts, int tendered})> submitted;
  late bool submitSucceeds;

  Future<void> pump(WidgetTester tester) async {
    submitted = [];
    // A phone-sized surface: the keypad, list and actions must all fit, as on the device.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      // The real theme: the payment dialog reads the DIKA colour extension, as it does in the app.
      theme: buildLightTheme(),
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: NotaCalculatorBody(
          notaNumber: 7,
          taxRule: null,
          clock: () => DateTime(2026, 9, 19, 9, 5),
          onSubmit: (amounts, tendered) async {
            submitted.add((amounts: amounts, tendered: tendered));
            return submitSucceeds;
          },
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> keys(WidgetTester tester, List<String> names) async {
    for (final n in names) {
      await tester.tap(find.byKey(ValueKey('nota-key-$n')));
      await tester.pump();
    }
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  setUp(() => submitSucceeds = true);

  testWidgets('keying builds the current value, and ↵ moves it into the list and the total',
      (tester) async {
    await pump(tester);
    expect(find.text('Nota #7'), findsOneWidget);
    expect(find.text('Sab, 19 Sep'), findsOneWidget);

    await keys(tester, ['2', '5', '000']);
    expect(textOf(tester, 'nota-current-value'), 'Rp 25.000');
    expect(textOf(tester, 'nota-total'), 'Rp 0');

    await keys(tester, ['enter']);
    expect(textOf(tester, 'nota-current-value'), 'Rp 0');
    expect(textOf(tester, 'nota-total'), 'Rp 25.000');
    expect(textOf(tester, 'nota-item-count'), '1 item');
    expect(find.text('Item 1'), findsOneWidget);

    await keys(tester, ['3', '000', 'enter']);
    expect(textOf(tester, 'nota-total'), 'Rp 28.000');
    expect(textOf(tester, 'nota-item-count'), '2 item');
  });

  testWidgets('Selesai is disabled until there is something to charge', (tester) async {
    await pump(tester);
    FilledButton selesai() => tester.widget(find.byKey(const ValueKey('nota-selesai')));
    expect(selesai().onPressed, isNull);
    await keys(tester, ['5']);
    expect(selesai().onPressed, isNotNull);
  });

  testWidgets('C clears the typed amount and keeps the list', (tester) async {
    await pump(tester);
    await keys(tester, ['4', '000', 'enter', '9', '9', 'clear']);
    expect(textOf(tester, 'nota-current-value'), 'Rp 0');
    expect(textOf(tester, 'nota-total'), 'Rp 4.000');
  });

  testWidgets('short cash reads "Kurang" and cannot finish; enough cash shows the change and submits',
      (tester) async {
    await pump(tester);
    await keys(tester, ['2', '5', '000', 'enter', '1', '2', '000', 'enter']);
    await tester.tap(find.byKey(const ValueKey('nota-selesai')));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'nota-pay-total'), 'Rp 37.000');
    FilledButton finish() => tester.widget(find.byKey(const ValueKey('nota-pay-finish')));

    await tester.enterText(find.byKey(const ValueKey('nota-tender-field')), '30000');
    await tester.pump();
    expect(find.text('Kurang'), findsOneWidget);
    expect(find.text('Rp 7.000'), findsOneWidget);
    expect(finish().onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('nota-tender-field')), '50000');
    await tester.pump();
    expect(find.text('Kembalian'), findsOneWidget);
    expect(find.text('Rp 13.000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nota-pay-finish')));
    await tester.pumpAndSettle();

    expect(submitted, hasLength(1));
    expect(submitted.single.amounts, [25000, 12000]);
    expect(submitted.single.tendered, 50000);
    // Recorded, so the keypad is ready for the next customer.
    expect(textOf(tester, 'nota-total'), 'Rp 0');
    expect(textOf(tester, 'nota-item-count'), '0 item');
  });

  testWidgets('an amount typed but never entered is still charged', (tester) async {
    await pump(tester);
    await keys(tester, ['2', '000', 'enter', '5', '000']);
    await tester.tap(find.byKey(const ValueKey('nota-selesai')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'nota-pay-total'), 'Rp 7.000');

    await tester.enterText(find.byKey(const ValueKey('nota-tender-field')), '10000');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nota-pay-finish')));
    await tester.pumpAndSettle();
    expect(submitted.single.amounts, [2000, 5000]);
  });

  testWidgets('a failed save keeps the nota on screen — nothing was recorded, so nothing is lost',
      (tester) async {
    submitSucceeds = false;
    await pump(tester);
    await keys(tester, ['8', '000', 'enter']);
    await tester.tap(find.byKey(const ValueKey('nota-selesai')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nota-tender-field')), '10000');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nota-pay-finish')));
    await tester.pumpAndSettle();

    expect(submitted, hasLength(1));
    expect(textOf(tester, 'nota-total'), 'Rp 8.000');
  });

  testWidgets('Kembali closes the dialog and changes nothing', (tester) async {
    await pump(tester);
    await keys(tester, ['6', '000', 'enter']);
    await tester.tap(find.byKey(const ValueKey('nota-selesai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nota-pay-back')));
    await tester.pumpAndSettle();

    expect(submitted, isEmpty);
    expect(textOf(tester, 'nota-total'), 'Rp 6.000');
  });

  testWidgets('Batal asks first, and only a confirmed cancel empties the nota', (tester) async {
    await pump(tester);
    await keys(tester, ['6', '000', 'enter']);

    await tester.tap(find.byKey(const ValueKey('nota-batal')));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan nota ini?'), findsOneWidget);
    await tester.tap(find.text('Tidak'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'nota-total'), 'Rp 6.000');

    await tester.tap(find.byKey(const ValueKey('nota-batal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, batalkan'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'nota-total'), 'Rp 0');
    expect(submitted, isEmpty);
  });
}
