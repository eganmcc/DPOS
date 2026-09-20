import 'package:dpos/features/stt/stt_engine.dart';
import 'package:dpos/features/stt/stt_options.dart';
import 'package:dpos/features/stt/stt_runner.dart';
import 'package:flutter_test/flutter_test.dart';

/// The listening machinery on its own, with no screen attached.
class _FakeEngine implements SttEngine {
  int listenCount = 0;
  int stopCount = 0;
  bool engineListening = false;
  bool startsOk = true;

  /// What the engine would send to whoever registered LAST — which is the whole point of the
  /// test below.
  void Function(String status)? onStatus;
  void Function(SttFailure failure)? onError;
  void Function(String text, double? confidence, bool isFinal)? onResult;

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
    // The real engine forwards through a stable indirection, so the newest caller wins. A fake
    // that kept the FIRST one would hide exactly the bug this guards.
    this.onStatus = onStatus;
    this.onError = onError;
    return true;
  }

  @override
  Future<List<SttLocale>> locales() async => const [SttLocale('in_ID', 'Indonesia')];

  @override
  Future<bool> listen({
    required SttOptions options,
    required void Function(String text, double? confidence, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
  }) async {
    listenCount++;
    this.onResult = onResult;
    engineListening = startsOk;
    return startsOk;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    engineListening = false;
  }

  @override
  Future<void> cancel() async => engineListening = false;
}

void main() {
  late _FakeEngine engine;

  SttRunner runner({SttOptions options = const SttOptions(), void Function(String)? onUtterance}) =>
      SttRunner(
        engine: engine,
        options: options,
        restartDelay: Duration.zero,
        watchdogPeriod: const Duration(milliseconds: 20),
        onUtterance: onUtterance,
      );

  setUp(() => engine = _FakeEngine());

  test('the newest screen to initialise is the one the engine talks to', () async {
    // The stuck stop button, 20 Sep: the engine is one shared instance, and the plugin returns
    // early once initialised. The second screen's callbacks were dropped, so the statuses went on
    // reaching a screen that was gone and the live one waited forever.
    final first = runner();
    await first.init();
    final second = runner();
    await second.init();

    await second.start();
    engine.onStatus!('done');

    expect(second.listening, false, reason: 'the live screen heard the session end');
    expect(second.wantListening, false, reason: 'and its button went back to Dengarkan');
    expect(first.listening, false, reason: 'the old one was never listening to begin with');
  });

  test('a session that ends clears the intent, so the button cannot lie', () async {
    final r = runner();
    await r.init();
    await r.start();
    expect(r.wantListening, true);

    engine.onStatus!('notListening');
    expect(r.wantListening, false);
    expect(r.listening, false);
  });

  test('every ending hands the words over exactly once', () async {
    final heard = <String>[];
    final r = runner(onUtterance: heard.add);
    await r.init();
    await r.start();

    r.transcript.onResult('nasi goreng dua', null, isFinal: false); // partial only
    engine.onStatus!('done'); // the session ends without a final
    engine.onStatus!('done'); // and Android says so twice, as it does

    expect(heard, ['nasi goreng dua']);
  });

  test('a refused listen does not leave the run armed', () async {
    engine.startsOk = false;
    final r = runner();
    await r.init();
    await r.start();

    expect(r.listening, false);
    expect(r.wantListening, false);
  });

  test('it listens in Indonesian under whatever code the device uses', () async {
    final r = runner();
    await r.init();
    expect(r.listenOptions.localeId, 'in_ID');
  });

  test('a permanent error stops the run instead of spinning', () async {
    final r = runner(options: const SttOptions(continuous: true));
    await r.init();
    await r.start();
    engine.onError!(const SttFailure('error_client', permanent: true));

    expect(r.wantListening, false);
  });
}
