import 'package:dpos/core/theme.dart';
import 'package:dpos/data/models.dart';
import 'package:dpos/features/stt/stt_engine.dart';
import 'package:dpos/features/stt/stt_lab_screen.dart';
import 'package:dpos/features/stt/stt_options.dart';
import 'package:dpos/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The voice bench end to end, minus the microphone: the fake engine below hands back the
/// callbacks so a test can deliver partials, finals, statuses and errors exactly as a handset
/// would — including the misbehaviour the real one is known for.
class FakeSttEngine implements SttEngine {
  FakeSttEngine({this.supported = true, this.initialises = true, this.offered = const []});

  final bool supported;
  bool initialises;
  List<SttLocale> offered;

  /// What `listen()` answers. False is the refusal the plugin tells us about.
  bool startsOk = true;

  /// Whether the microphone actually opens after a listen that reported success. False is the
  /// SILENT refusal: Android says no, the plugin returns anyway, and no callback ever arrives.
  bool liveAfterStart = true;

  bool engineListening = false;

  int initCount = 0;
  int restartCount = 0;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  SttOptions? lastListenOptions;

  void Function(String status)? emitStatus;
  void Function(SttFailure failure)? emitError;
  void Function(String text, double? confidence, bool isFinal)? emitResult;
  void Function(double level)? emitLevel;

  @override
  bool get isSupported => supported;

  @override
  bool get isListening => engineListening;

  @override
  Future<bool> initialize({
    required SttOptions options,
    required void Function(String status) onStatus,
    required void Function(SttFailure failure) onError,
    bool restart = false,
  }) async {
    initCount++;
    if (restart) restartCount++;
    emitStatus = onStatus;
    emitError = onError;
    return initialises;
  }

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
    emitLevel = onSoundLevel;
    engineListening = startsOk && liveAfterStart;
    return startsOk;
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
  late FakeSttEngine engine;
  late SttOptions options;
  late bool micGranted;
  late List<Product> catalog;
  late int settingsOpened;

  Future<void> pump(WidgetTester tester) async {
    settingsOpened = 0;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: SttLabBody(
            engine: engine,
            options: options,
            onOptions: (o) => setState(() => options = o),
            requestMicPermission: () async => micGranted,
            openSettings: () async => settingsOpened++,
            clock: () => DateTime(2026, 9, 20, 10, 0, 0),
            restartDelay: Duration.zero,
            watchdogPeriod: const Duration(milliseconds: 20),
            catalog: catalog,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The tuning knobs sit below the fold, and a ListView does not build what it cannot show.
  /// [delta] is negative to scroll back UP — scrollUntilVisible only searches one way.
  Future<void> scrollTo(WidgetTester tester, String key, {double delta = 250}) async {
    await tester.scrollUntilVisible(find.byKey(ValueKey(key)), delta,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  setUp(() {
    engine = FakeSttEngine(offered: const [SttLocale('in_ID', 'Indonesia'), SttLocale('en_US', 'English')]);
    options = const SttOptions();
    micGranted = true;
    // A small shop: one item with stock, one sold out, one untracked.
    Variant v(String n, {bool tracked = true, int? stock}) => Variant(
        id: 'v-$n', name: n, price: 10000, sku: null,
        isAvailable: true, trackInventory: tracked, stock: stock);
    catalog = [
      Product(id: 'p1', name: 'Nasi Goreng', categoryName: 'Makanan', isAvailable: true,
          variants: [v('Porsi', stock: 5)], modifierGroups: const []),
      Product(id: 'p2', name: 'Es Teh Manis', categoryName: 'Minuman', isAvailable: true,
          variants: [v('Gelas', stock: 0)], modifierGroups: const []),
    ];
  });

  testWidgets('on a device that is not Android it says so instead of pretending', (tester) async {
    engine = FakeSttEngine(supported: false);
    await pump(tester);
    expect(find.text('Input suara baru tersedia di Android.'), findsOneWidget);
    expect(find.byKey(const ValueKey('stt-mic')), findsNothing);
  });

  testWidgets('shows which locale this device calls Indonesian — the in_ID trap', (tester) async {
    await pump(tester);
    expect(find.text('Bahasa Indonesia di perangkat ini: in_ID'), findsOneWidget);
  });

  testWidgets('with no Indonesian locale offered, it says that plainly', (tester) async {
    engine = FakeSttEngine(offered: const [SttLocale('en_US', 'English')]);
    await pump(tester);
    expect(find.textContaining('tidak menyediakan pengenalan Bahasa Indonesia'), findsOneWidget);
  });

  testWidgets('with no recognizer at all, the mic is disabled and the fix is suggested',
      (tester) async {
    engine = FakeSttEngine(initialises: false);
    await pump(tester);
    final mic = tester.widget<FilledButton>(find.byKey(const ValueKey('stt-mic')));
    expect(mic.onPressed, isNull);
    expect(find.textContaining('androidIntentLookup'), findsOneWidget);
  });

  testWidgets('a session: listen, live partial, final result', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();
    expect(engine.listenCount, 1);
    // The device's own Indonesian code is used when the option is left on automatic.
    expect(engine.lastListenOptions!.localeId, 'in_ID');

    engine.emitResult!('nasi goreng', null, false);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('stt-live'))).data, 'nasi goreng');

    engine.emitResult!('nasi goreng dua', 0.92, true);
    await tester.pump();
    expect(find.text('nasi goreng dua'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('stt-live'))).data,
        'Tekan Dengarkan lalu bicara…');
  });

  testWidgets('a mid-sentence buffer reset is caught and counted, not lost', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();

    engine.emitResult!('buncis 20', null, false);
    await tester.pump();
    engine.emitResult!('', null, false); // the recognizer silently starts over
    await tester.pump();

    expect(find.text('buncis 20'), findsOneWidget, reason: 'the words survived the reset');
    expect(find.text('buffer resets: 1'), findsOneWidget);
  });

  testWidgets('a status of done flushes what was heard and stops listening', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();

    engine.emitResult!('tiga ribu', null, false);
    await tester.pump();
    engine.emitStatus!('done');
    await tester.pumpAndSettle();

    expect(find.text('tiga ribu'), findsOneWidget);
    expect(find.text('Dengarkan'), findsOneWidget, reason: 'back to idle');
  });

  testWidgets('an error keeps the words already heard and shows the code', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();

    engine.emitResult!('setengah', null, false);
    await tester.pump();
    engine.emitError!(const SttFailure('error_no_match'));
    await tester.pumpAndSettle();

    expect(find.text('setengah'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('stt-status'))).data,
        'Status: error_no_match');
  });

  testWidgets('stopping by hand flushes too', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();
    engine.emitResult!('lima belas ribu', null, false);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('stt-mic'))); // now "Berhenti"
    await tester.pumpAndSettle();

    expect(engine.stopCount, 1);
    expect(find.text('lima belas ribu'), findsOneWidget);
  });

  testWidgets('a denied microphone offers settings and never starts a session', (tester) async {
    micGranted = false;
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();

    expect(find.text('Perlu izin mikrofon'), findsOneWidget);
    await tester.tap(find.text('Buka pengaturan'));
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);
    expect(engine.listenCount, 0);
  });

  testWidgets('a listen the plugin refuses ends the session instead of pretending', (tester) async {
    await pump(tester);
    engine.startsOk = false;
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();

    expect(find.text('Dengarkan'), findsOneWidget, reason: 'the button is back to start');
    expect(find.textContaining('stopped'), findsOneWidget, reason: 'and the status says so too');
  });

  testWidgets('a microphone that closes without a callback is caught by the watchdog',
      (tester) async {
    await pump(tester);
    // listen() reports success, but the platform never actually opens the microphone — the
    // failure that used to leave the button stuck on "Berhenti" forever.
    engine.liveAfterStart = false;
    await tester.tap(find.byKey(const ValueKey('stt-mic')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Dengarkan'), findsOneWidget);
    expect(find.text('Berhenti'), findsNothing);
  });

  group('continuous mode — keep listening until stop is pressed', () {
    setUp(() => options = const SttOptions(continuous: true));

    testWidgets('a session ending on silence starts the next one by itself', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();
      expect(engine.listenCount, 1);

      engine.emitResult!('nasi goreng', 0.9, true);
      engine.emitStatus!('done'); // the plugin always ends a session; continuous starts another
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.listenCount, 2, reason: 'listening continues without another tap');
      expect(find.text('nasi goreng'), findsOneWidget);
      expect(find.text('restarts: 1'), findsOneWidget);
      // Still armed, so the button still offers to stop.
      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('each stretch lands as its own result', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      engine.emitResult!('es teh satu', null, true);
      engine.emitStatus!('done');
      await tester.pump(const Duration(milliseconds: 50));
      engine.emitResult!('nasi goreng dua', null, true);
      engine.emitStatus!('done');
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('es teh satu'), findsOneWidget);
      expect(find.text('nasi goreng dua'), findsOneWidget);
    });

    testWidgets('pressing stop really stops — a late status cannot restart it', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('stt-mic'))); // stop
      await tester.pumpAndSettle();
      final after = engine.listenCount;

      // The stop itself produces a status callback; it must not be read as "start another".
      engine.emitStatus!('notListening');
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.listenCount, after);
      expect(find.text('Dengarkan (terus)'), findsOneWidget);
    });

    testWidgets('a recoverable error just starts the next stretch', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      // Silence in a quiet shop looks exactly like this, and must not end the run.
      engine.emitError!(const SttFailure('error_no_match'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.listenCount, 2);
    });

    testWidgets('a permanent error stops the run instead of spinning', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      engine.emitError!(const SttFailure('error_client', permanent: true));
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.listenCount, 1, reason: 'trying again would fail the same way');
      expect(find.text('Dengarkan (terus)'), findsOneWidget);
    });

    testWidgets('a long run of sessions that hear nothing gives up rather than burn the battery',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      for (var i = 0; i < 20; i++) {
        engine.emitStatus!('done');
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(engine.listenCount, lessThan(20));
      expect(find.text('Dengarkan (terus)'), findsOneWidget, reason: 'it stopped itself');
    });

    testWidgets('a stretch that heard something resets the give-up counter', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      for (var i = 0; i < 30; i++) {
        // Every few empty stretches, someone actually says something.
        if (i % 5 == 0) engine.emitResult!('halo $i', null, true);
        engine.emitStatus!('done');
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Berhenti'), findsOneWidget, reason: 'still listening');
    });

    testWidgets('a session that dies in silence is noticed and the run continues', (tester) async {
      // The reported bug: Android refuses the restart, the plugin returns without arming
      // anything, and NO callback ever arrives. Nothing used to notice.
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();
      expect(engine.listenCount, 1);

      engine.engineListening = false; // the microphone quietly closed
      await tester.pump(const Duration(milliseconds: 120));

      expect(engine.listenCount, greaterThan(1), reason: 'the watchdog restarted it');
    });

    testWidgets('a listen the plugin refuses does not leave the button offering to stop',
        (tester) async {
      await pump(tester);
      engine.startsOk = false;
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      // It retries, then gives up — and what it must never do is keep saying "Berhenti" while
      // the microphone is shut.
      expect(find.text('Dengarkan (terus)'), findsOneWidget);
      expect(find.text('Berhenti'), findsNothing);
    });

    testWidgets('a busy recognizer is rebuilt before the next session, not merely retried',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();
      expect(engine.restartCount, 0);

      // error_busy means the recognizer object itself is no good; asking it again fails the same
      // way. error_no_match, by contrast, is just a quiet shop.
      engine.emitError!(const SttFailure('error_busy'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.restartCount, 1, reason: 'the engine was rebuilt');
      expect(engine.listenCount, 2);
    });

    testWidgets('silence does NOT rebuild the engine', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      engine.emitError!(const SttFailure('error_no_match'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.restartCount, 0, reason: 'nobody spoke; nothing is broken');
    });

    testWidgets('an error and a status for the SAME ending count as one, not two', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      // Android routinely delivers both for one silence. Two restarts would mean two recognizers.
      engine.emitError!(const SttFailure('error_no_match'));
      engine.emitStatus!('done');
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.listenCount, 2, reason: 'one ending, one restart');
    });

    testWidgets('saying the stop phrase ends the run and keeps the order', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      engine.emitResult!('ayam bakar dua pesanan selesai', 0.9, true);
      await tester.pumpAndSettle();

      expect(engine.stopCount, 1, reason: 'the microphone was released');
      expect(find.text('Dengarkan (terus)'), findsOneWidget, reason: 'and the run is over');
      expect(find.text('ayam bakar dua'), findsOneWidget,
          reason: 'the order is kept, without the instruction');
    });

    testWidgets('a late repeat of the stop phrase does not record itself', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      // Android sends the partial and then the final for the same words.
      engine.emitResult!('nasi goreng satu pesanan selesai', null, false);
      await tester.pumpAndSettle();
      engine.emitResult!('nasi goreng satu pesanan selesai', null, true);
      await tester.pumpAndSettle();

      expect(find.text('nasi goreng satu'), findsOneWidget, reason: 'recorded once, not twice');
      expect(find.textContaining('pesanan selesai'), findsNothing);
    });

    testWidgets('an ordinary order keeps the run going', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      engine.emitResult!('ayam bakar dua', 0.9, true);
      engine.emitStatus!('done');
      await tester.pump(const Duration(milliseconds: 50));

      expect(engine.stopCount, 0);
      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('leaving the screen mid-run releases the microphone', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.cancelCount, 1);
    });
  });

  group('checking what was heard against stock', () {
    /// Turn on the stock radio, then hear one line.
    Future<void> hear(WidgetTester tester, String said) async {
      await scrollTo(tester, 'stt-mode-stock');
      await tester.tap(find.byKey(const ValueKey('stt-mode-stock')));
      await tester.pumpAndSettle();
      await scrollTo(tester, 'stt-mic', delta: -250);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();
      engine.emitResult!(said, 0.9, true);
      await tester.pumpAndSettle();
    }

    testWidgets('an item in stock is shown as sellable, with what is left', (tester) async {
      await pump(tester);
      await hear(tester, 'nasi goreng dua');
      expect(find.byKey(const ValueKey('stt-verdict-ok')), findsOneWidget);
      expect(find.text('Nasi Goreng ×2 — sisa 5'), findsOneWidget);
    });

    testWidgets('two items said in one breath get a verdict each', (tester) async {
      // Exactly what the device run produced as a single line on 20 Sep.
      await pump(tester);
      await hear(tester, 'nasi goreng 2 es teh manis 1');
      expect(find.byKey(const ValueKey('stt-verdict-ok')), findsOneWidget);
      expect(find.byKey(const ValueKey('stt-verdict-outOfStock')), findsOneWidget);
      expect(find.text('Nasi Goreng ×2 — sisa 5'), findsOneWidget);
    });

    testWidgets('an item nobody sells is called out', (tester) async {
      await pump(tester);
      await hear(tester, 'bakso urat satu');
      expect(find.byKey(const ValueKey('stt-verdict-notFound')), findsOneWidget);
      expect(find.text('Tidak ada di katalog'), findsOneWidget);
    });

    testWidgets('a sold-out item says so, with the real number', (tester) async {
      await pump(tester);
      await hear(tester, 'es teh manis satu');
      expect(find.byKey(const ValueKey('stt-verdict-outOfStock')), findsOneWidget);
      expect(find.textContaining('sisa 0'), findsOneWidget);
    });

    testWidgets('asking for more than is left shows how many there actually are', (tester) async {
      await pump(tester);
      await hear(tester, 'nasi goreng sepuluh');
      expect(find.byKey(const ValueKey('stt-verdict-insufficient')), findsOneWidget);
      expect(find.text('Nasi Goreng — sisa 5, diminta 10'), findsOneWidget);
    });

    testWidgets('text-only mode passes no judgement', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();
      engine.emitResult!('bakso urat satu', null, true);
      await tester.pumpAndSettle();

      expect(find.text('bakso urat satu'), findsOneWidget);
      expect(find.byKey(const ValueKey('stt-verdict-notFound')), findsNothing);
    });

    testWidgets('an account with no catalogue says so instead of marking everything missing',
        (tester) async {
      catalog = const [];
      await pump(tester);
      await scrollTo(tester, 'stt-mode-stock');
      await tester.tap(find.byKey(const ValueKey('stt-mode-stock')));
      await tester.pumpAndSettle();
      expect(find.text('Akun ini tidak punya katalog untuk dicek.'), findsOneWidget);
    });
  });

  group('tuning', () {
    testWidgets('pauseFor changes what the next session actually uses', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'stt-pauseFor-up');
      await tester.tap(find.byKey(const ValueKey('stt-pauseFor-up')));
      await tester.pumpAndSettle();
      expect(options.pauseForSeconds, 4);

      await scrollTo(tester, 'stt-mic', delta: -250);
      await tester.tap(find.byKey(const ValueKey('stt-mic')));
      await tester.pumpAndSettle();
      expect(engine.lastListenOptions!.pauseForSeconds, 4);
    });

    testWidgets('pauseFor will not go below 2s, where a session dies before you speak',
        (tester) async {
      await pump(tester);
      await scrollTo(tester, 'stt-pauseFor-down');
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('stt-pauseFor-down')));
        await tester.pumpAndSettle();
      }
      expect(options.pauseForSeconds, SttOptions.minPauseSeconds);
    });

    testWidgets('an initialize-level option restarts the engine; a listen-level one does not',
        (tester) async {
      await pump(tester);
      final before = engine.restartCount;

      await scrollTo(tester, 'stt-partialResults');
      await tester.tap(find.byKey(const ValueKey('stt-partialResults')));
      await tester.pumpAndSettle();
      expect(engine.restartCount, before, reason: 'partialResults belongs to listen()');

      await scrollTo(tester, 'stt-androidNoBluetooth');
      await tester.tap(find.byKey(const ValueKey('stt-androidNoBluetooth')));
      await tester.pumpAndSettle();
      expect(options.androidNoBluetooth, true);
      expect(engine.restartCount, before + 1, reason: 'this one is set at initialize()');
    });
  });
}
