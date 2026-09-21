import 'package:dpos/core/theme.dart';
import 'package:dpos/data/models.dart';
import 'package:dpos/features/stt/stt_engine.dart';
import 'package:dpos/features/stt/stt_options.dart';
import 'package:dpos/features/stt/stt_stock_check.dart';
import 'package:dpos/features/stt/voice_order_parse.dart';
import 'package:dpos/features/stt/voice_order_screen.dart';
import 'package:dpos/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taking an order by voice, without a microphone and without a server: the fake engine speaks,
/// the spy records what the till would have been asked to do.
class _FakeEngine implements SttEngine {
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  bool engineListening = false;
  void Function(String status)? emitStatus;
  void Function(SttFailure failure)? emitError;
  void Function(String text, double? confidence, bool isFinal)? emitResult;

  @override
  bool get isSupported => true;

  @override
  bool get isListening => engineListening;

  @override
  Future<bool> initialize({
    required SttOptions options,
    required void Function(String status) onStatus,
    required void Function(SttFailure failure) onError,
    bool restart = false,
  }) async {
    emitStatus = onStatus;
    emitError = onError;
    return true;
  }

  List<SttLocale> offered = const [SttLocale('en_US', 'English'), SttLocale('in_ID', 'Indonesia')];
  SttOptions? lastListenOptions;

  @override
  Future<List<SttLocale>> locales() async => offered;

  @override
  Future<bool> listen({
    required SttOptions options,
    required void Function(String text, double? confidence, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
  }) async {
    listenCount++;
    lastListenOptions = options;
    emitResult = onResult;
    engineListening = true;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    engineListening = false;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    engineListening = false;
  }
}

void main() {
  late _FakeEngine engine;
  late List<Product> catalog;
  late List<SttStockCheck> addedToCart;
  late List<SttStockCheck> finishedChecks;
  late List<PricedLine> finishedPriced;
  late VoiceOrderMode? finishedMode;
  late bool finishSucceeds;

  Variant v(String n, {int? stock, int price = 10000}) => Variant(
      id: 'v-$n', name: n, price: price, sku: null,
      isAvailable: true, trackInventory: stock != null, stock: stock);

  Future<void> pump(WidgetTester tester,
      {required VoiceOrderMode mode, SttOptions options = const SttOptions()}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VoiceOrderBody(
          engine: engine,
          options: options,
          catalog: catalog,
          taxRule: null,
          initialMode: mode,
          requestMicPermission: () async => true,
          openSettings: () async {},
          onAddToCart: addedToCart.addAll,
          onFinish: (m, checks, priced) async {
            finishedMode = m;
            finishedChecks = checks;
            finishedPriced = priced;
            return finishSucceeds;
          },
          restartDelay: Duration.zero,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Tap the mic and say one line, the way a handset delivers it.
  Future<void> say(WidgetTester tester, String words) async {
    if (engine.listenCount == 0) {
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();
    }
    engine.emitResult!(words, 0.9, true);
    await tester.pumpAndSettle();
  }

  setUp(() {
    engine = _FakeEngine();
    addedToCart = [];
    finishedChecks = [];
    finishedPriced = [];
    finishedMode = null;
    finishSucceeds = true;
    catalog = [
      Product(id: 'p1', name: 'Nasi Goreng', categoryName: 'Makanan', isAvailable: true,
          variants: [v('Porsi', stock: 5, price: 25000)], modifierGroups: const []),
      Product(id: 'p2', name: 'Es Teh Manis', categoryName: 'Minuman', isAvailable: true,
          variants: [v('Gelas', stock: 0, price: 5000)], modifierGroups: const []),
    ];
  });

  group('ordering from the catalogue', () {
    testWidgets('a spoken item becomes a priced line', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua');

      expect(find.text('Nasi Goreng'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-total')), findsOneWidget);
      expect(find.text('Rp 50.000'), findsWidgets, reason: '2 × 25.000, priced by the catalogue');
    });

    testWidgets('two items in one breath become two lines', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng 2 es teh manis 1');

      expect(find.text('Nasi Goreng'), findsOneWidget);
      expect(find.text('Es Teh Manis'), findsOneWidget);
    });

    testWidgets('a line can be removed before it becomes money', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua');
      await tester.tap(find.byKey(const ValueKey('voice-remove-0')));
      await tester.pumpAndSettle();

      expect(find.text('Nasi Goreng'), findsNothing);
      expect(find.byKey(const ValueKey('voice-empty')), findsOneWidget);
    });

    testWidgets('an item nobody sells blocks Selesai until it is dealt with', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'roti bakar satu');

      expect(find.byKey(const ValueKey('voice-blocked')), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('voice-selesai')));
      expect(button.onPressed, isNull, reason: 'a line nobody understood cannot be charged for');

      await tester.tap(find.byKey(const ValueKey('voice-remove-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('voice-blocked')), findsNothing);
    });

    testWidgets('sold out is shown but does NOT block — the shelf knows better', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'es teh manis satu');

      expect(find.byKey(const ValueKey('voice-problem-0')), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('voice-selesai')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Tambah ke keranjang hands the lines to the cart', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua');
      await tester.tap(find.byKey(const ValueKey('voice-add-to-cart')));
      await tester.pumpAndSettle();

      expect(addedToCart.length, 1);
      expect(addedToCart.single.product!.name, 'Nasi Goreng');
      expect(addedToCart.single.qty, 2);
    });

    testWidgets('Selesai sends exactly what is on screen', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua es teh manis satu');
      await tester.tap(find.byKey(const ValueKey('voice-remove-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('voice-selesai')));
      await tester.pumpAndSettle();

      expect(finishedMode, VoiceOrderMode.catalogue);
      expect(finishedChecks.length, 1, reason: 'the removed line is not sent');
      expect(finishedChecks.single.product!.name, 'Nasi Goreng');
    });
  });

  group('ordering at a spoken price', () {
    testWidgets('"Pecel lele 100" is one item at a hundred thousand', (tester) async {
      await pump(tester, mode: VoiceOrderMode.openPrice);
      await say(tester, 'pecel lele 100');

      expect(find.text('pecel lele'), findsOneWidget);
      expect(find.text('Rp 100.000'), findsWidgets);
    });

    testWidgets('an item with no price blocks Selesai and says why', (tester) async {
      await pump(tester, mode: VoiceOrderMode.openPrice);
      await say(tester, 'pecel lele');

      expect(find.text('Harga belum disebut'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('voice-selesai')));
      expect(button.onPressed, isNull);
    });

    testWidgets('there is no cart to add to, so no such button', (tester) async {
      await pump(tester, mode: VoiceOrderMode.openPrice);
      await say(tester, 'pecel lele 100');
      expect(find.byKey(const ValueKey('voice-add-to-cart')), findsNothing);
    });

    testWidgets('Selesai hands over the priced lines', (tester) async {
      await pump(tester, mode: VoiceOrderMode.openPrice);
      await say(tester, 'pecel lele 100 es teh 5');
      await tester.tap(find.byKey(const ValueKey('voice-selesai')));
      await tester.pumpAndSettle();

      expect(finishedMode, VoiceOrderMode.openPrice);
      expect(finishedPriced.length, 2);
      expect(finishedPriced.first.price, 100000);
      expect(finishedPriced.last.price, 5000);
    });
  });

  /// An utterance does not only finish with a final result. It also finishes when the session's
  /// status says so, when an error ends it, when the user presses stop, and when the next session
  /// starts and finds something left over. Every one of those has to reach the bill — the first
  /// version staged lines from the final only, so anything said into a session that ended another
  /// way was heard, shown live, and silently never listed.
  group('every way an utterance can end reaches the bill', () {
    testWidgets('a session that ends on silence, with no final result', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      engine.emitResult!('nasi goreng dua', 0.9, false); // partial only
      engine.emitStatus!('done');
      await tester.pumpAndSettle();

      expect(find.text('Nasi Goreng'), findsOneWidget);
    });

    testWidgets('a session that ends on an error', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      engine.emitResult!('nasi goreng dua', 0.9, false);
      engine.emitError!(const SttFailure('error_no_match'));
      await tester.pumpAndSettle();

      expect(find.text('Nasi Goreng'), findsOneWidget);
    });

    testWidgets('a session the cashier stops by hand', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      engine.emitResult!('nasi goreng dua', 0.9, false);
      await tester.tap(find.byKey(const ValueKey('voice-mic'))); // stop
      await tester.pumpAndSettle();

      expect(find.text('Nasi Goreng'), findsOneWidget);
    });

    testWidgets('a session stopped by the spoken phrase', (tester) async {
      await pump(tester, mode: VoiceOrderMode.openPrice);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      engine.emitResult!('pecel lele 100', null, false);
      engine.emitResult!('selesai', null, false);
      await tester.pumpAndSettle();

      expect(find.text('pecel lele'), findsOneWidget);
      expect(engine.stopCount, 1);
    });

    testWidgets('words that land after the session has already closed', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      // The straggler: the session is done, its last words arrive, and the next session starts.
      engine.emitStatus!('done');
      engine.emitResult!('nasi goreng dua', 0.9, false);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      expect(find.text('Nasi Goreng'), findsOneWidget);
    });
  });

  /// The device, 22:05: "ayam geprek keju 5" arrived as the words, a 5.9-second gap, and then the
  /// number — with the recognizer's buffer thrown away in between. The name was staged at a
  /// quantity of one and the number turned up as an item nobody sells.
  group('a number that arrives after its item', () {
    testWidgets('becomes that item\'s quantity, not a line of its own', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng');
      await say(tester, '5');

      expect(find.text('Nasi Goreng'), findsOneWidget, reason: 'still one line');
      expect(find.text('5'), findsOneWidget, reason: 'and that is the quantity column');
      expect(find.byKey(const ValueKey('voice-blocked')), findsNothing,
          reason: 'no phantom item nobody sells');
    });

    testWidgets('the verdict is recomputed, not patched', (tester) async {
      // Five is more than the five in stock is fine; ten is not, and the line has to say so.
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng');
      await say(tester, 'sepuluh');

      expect(find.byKey(const ValueKey('voice-problem-0')), findsOneWidget);
      expect(find.textContaining('sisa 5'), findsOneWidget);
    });

    testWidgets('spelled out, it works the same', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng');
      await say(tester, 'dua');
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('at a spoken price the stranded number is the price', (tester) async {
      await pump(tester, mode: VoiceOrderMode.openPrice);
      await say(tester, 'pecel lele');
      await say(tester, '100');

      expect(find.text('pecel lele'), findsOneWidget);
      expect(find.text('Rp 100.000'), findsWidgets);
      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('voice-selesai')));
      expect(button.onPressed, isNotNull, reason: 'the line is complete now');
    });

    testWidgets('a number with nothing before it is shown, not swallowed', (tester) async {
      // It attaches to nothing, so it stays visible as a line the cashier can see and remove.
      // Dropping it silently would be the failure this screen must never have, and Selesai is
      // blocked until it is dealt with either way.
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, '5');

      expect(find.byKey(const ValueKey('voice-empty')), findsNothing);
      expect(find.byKey(const ValueKey('voice-blocked')), findsOneWidget);
    });
  });

  group('the sheet itself', () {
    testWidgets('the mode cannot change once there is a bill to lose', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      final before = tester
          .widget<SegmentedButton<VoiceOrderMode>>(find.byKey(const ValueKey('voice-mode')));
      expect(before.onSelectionChanged, isNotNull);

      await say(tester, 'nasi goreng dua');
      final after = tester
          .widget<SegmentedButton<VoiceOrderMode>>(find.byKey(const ValueKey('voice-mode')));
      expect(after.onSelectionChanged, isNull);
    });

    testWidgets('"pesanan selesai" stops the listening and keeps the order', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua pesanan selesai');

      expect(engine.stopCount, 1);
      expect(find.text('Nasi Goreng'), findsOneWidget);
    });

    testWidgets('a split "pesanan selesai" is still the instruction, never an item',
        (tester) async {
      // What the handset did: the phrase arrived as two separate results.
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua pesanan');
      await say(tester, 'selesai');

      expect(find.text('selesai'), findsNothing, reason: 'it was an instruction, not an order');
      expect(find.byKey(const ValueKey('voice-problem-0')), findsNothing);
      expect(find.text('Nasi Goreng'), findsOneWidget);
      expect(engine.stopCount, 1, reason: 'and it stopped the run, as asked');
    });

    testWidgets('an item added after stopping and starting again reaches the list',
        (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua');
      await tester.tap(find.byKey(const ValueKey('voice-mic'))); // stop
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('voice-mic'))); // start again
      await tester.pumpAndSettle();
      engine.emitResult!('nasi goreng dua', 0.9, true);
      await tester.pumpAndSettle();

      expect(find.text('Nasi Goreng'), findsNWidgets(2),
          reason: 'said again on purpose after a stop — two lines, not one swallowed');
    });

    testWidgets('a failed submit keeps the bill on screen', (tester) async {
      finishSucceeds = false;
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await say(tester, 'nasi goreng dua');
      await tester.tap(find.byKey(const ValueKey('voice-selesai')));
      await tester.pumpAndSettle();

      expect(find.text('Nasi Goreng'), findsOneWidget,
          reason: 'nothing was recorded, so nothing may be cleared');
    });

    testWidgets('the till keeps listening through a pause, whatever the bench is set to',
        (tester) async {
      // The device log for 21:57: a session ended at exactly 3.010s of quiet and the whole run
      // ended with it, so every item needed its own tap. An order has thinking in it.
      await pump(tester, mode: VoiceOrderMode.catalogue, options: const SttOptions());
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      expect(engine.lastListenOptions!.continuous, true);
      expect(engine.lastListenOptions!.pauseForSeconds, greaterThanOrEqualTo(6));
    });

    testWidgets('a longer pause tuned on the bench is honoured, not overruled', (tester) async {
      await pump(tester,
          mode: VoiceOrderMode.catalogue, options: const SttOptions(pauseForSeconds: 12));
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      expect(engine.lastListenOptions!.pauseForSeconds, 12);
    });

    testWidgets('a session that ends on silence starts the next one by itself', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();
      expect(engine.listenCount, 1);

      engine.emitStatus!('done');
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.listenCount, 2, reason: 'the run survives a gap between items');
      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('it listens in Indonesian, whatever language the phone is set to', (tester) async {
      // Android reports Indonesian as the legacy `in_ID`. Without this the recognizer would use
      // the phone's own default — English on an English phone — and hear nonsense.
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      expect(engine.lastListenOptions!.localeId, 'in_ID');
    });

    testWidgets('a locale chosen on the bench is not overridden', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue, options: const SttOptions(localeId: 'en_US'));
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();

      expect(engine.lastListenOptions!.localeId, 'en_US', reason: 'an explicit choice wins');
    });

    testWidgets('leaving mid-session releases the microphone', (tester) async {
      await pump(tester, mode: VoiceOrderMode.catalogue);
      await tester.tap(find.byKey(const ValueKey('voice-mic')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(engine.cancelCount, 1);
    });
  });
}
