import 'dart:io' show Platform;

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'stt_options.dart';

/// A locale the device's recognizer offers.
class SttLocale {
  final String id;
  final String name;
  const SttLocale(this.id, this.name);

  /// Android reports Indonesian with the LEGACY ISO 639 code `in`, not `id` — so a plain
  /// `startsWith('id')` finds nothing and the app wrongly concludes Indonesian is unavailable.
  bool get isIndonesian {
    final n = id.toLowerCase().replaceAll('-', '_');
    return n == 'id' || n.startsWith('id_') || n == 'in' || n.startsWith('in_');
  }
}

/// Why a session ended badly.
class SttFailure {
  final String code;
  final bool permanent;
  const SttFailure(this.code, {this.permanent = false});
}

/// The surface the lab screen talks to. An interface so the screen can be driven by a fake in
/// tests — the same injectable shape as `NotaChatBody`'s `readNota`.
abstract class SttEngine {
  /// True only where this feature is supported. Android-only by decision, not by accident.
  bool get isSupported;

  /// Whether the microphone is open RIGHT NOW, as the platform itself reports it.
  ///
  /// The caller needs this because a session can die without saying so (see [listen]), and a
  /// screen that trusts only its own flags then keeps claiming to listen long after it stopped.
  bool get isListening;

  /// Starts the plugin. Safe to call repeatedly; pass [restart] after changing an option that
  /// belongs to initialize() rather than listen().
  Future<bool> initialize({
    required SttOptions options,
    required void Function(String status) onStatus,
    required void Function(SttFailure failure) onError,
    bool restart = false,
  });

  Future<List<SttLocale>> locales();

  /// Starts one session. Returns false when the session did **not** start — no status or error
  /// callback will follow, so the caller must not sit waiting for one.
  ///
  /// True is not a promise either: the plugin ignores a platform that refuses to start, so the
  /// caller still has to watch [isListening].
  Future<bool> listen({
    required SttOptions options,
    required void Function(String text, double? confidence, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
  });

  Future<void> stop();
  Future<void> cancel();
}

/// The real engine.
///
/// Built like `core/tts.dart`: one instance, lazily started, and it **never throws** — a handset
/// with no recognizer must produce a clear message on screen, not a crash in a POS.
class RealSttEngine implements SttEngine {
  RealSttEngine({SpeechToText Function()? create}) : _create = create ?? SpeechToText.new;

  /// A FACTORY, not an instance, because a restart has to throw the old one away — see [initialize].
  final SpeechToText Function() _create;

  late SpeechToText _speech = _create();
  bool _ready = false;

  /// Android only, for now. On anything else the lab says so rather than half-working: the plugin
  /// does ship a federated Windows package, but nothing here is built or tested against it.
  @override
  bool get isSupported => !kIsWebLike && Platform.isAndroid;

  @override
  bool get isListening => _ready && _speech.isListening;

  @override
  Future<bool> initialize({
    required SttOptions options,
    required void Function(String status) onStatus,
    required void Function(SttFailure failure) onError,
    bool restart = false,
  }) async {
    if (!isSupported) return false;
    if (_ready && !restart) return true;
    try {
      if (restart) {
        await _speech.cancel();
        await _speech.stop();
        // A FRESH instance. `SpeechToText.initialize()` returns early the moment it has once
        // succeeded (`if (_initWorked) return`), so calling it again on the same object silently
        // ignores every initialize-level option — finalTimeout, the android* flags, logging. The
        // bench's re-init toggles were doing nothing at all until this.
        _speech = _create();
        _ready = false;
      }
      _ready = await _speech.initialize(
        onStatus: onStatus,
        onError: (SpeechRecognitionError e) =>
            onError(SttFailure(e.errorMsg, permanent: e.permanent)),
        debugLogging: options.debugLogging,
        finalTimeout: Duration(milliseconds: options.finalTimeoutMs),
        options: [
          if (options.androidNoBluetooth) SpeechToText.androidNoBluetooth,
          if (options.androidIntentLookup) SpeechToText.androidIntentLookup,
          if (options.androidAlwaysUseStop) SpeechToText.androidAlwaysUseStop,
        ],
      );
      return _ready;
    } catch (_) {
      // No recognizer, no permission, an OEM ROM that refuses — all the same to the caller.
      _ready = false;
      return false;
    }
  }

  @override
  Future<List<SttLocale>> locales() async {
    if (!_ready) return const [];
    try {
      final l = await _speech.locales();
      return [for (final x in l) SttLocale(x.localeId, x.name)];
    } catch (_) {
      return const [];
    }
  }

  /// What 7.4.0 actually does on a refused start, which is the whole reason for the bool: it asks
  /// the platform, and if the platform answers false it simply returns — no timers armed, no
  /// status, no error, `isListening` still false. Android refuses like that routinely when the
  /// previous recognizer has not let go yet, which is precisely what continuous mode provokes
  /// every few seconds. So: false here for the throwing case, and the caller's watchdog on
  /// [isListening] for the silent one.
  @override
  Future<bool> listen({
    required SttOptions options,
    required void Function(String text, double? confidence, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
  }) async {
    if (!_ready) return false;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) =>
            onResult(r.recognizedWords, r.confidence, r.finalResult),
        onSoundLevelChange: onSoundLevel,
        listenOptions: SpeechListenOptions(
          partialResults: options.partialResults,
          cancelOnError: options.cancelOnError,
          onDevice: options.onDevice,
          listenFor: Duration(seconds: options.listenForSeconds),
          pauseFor: Duration(seconds: options.pauseForSeconds),
          localeId: options.localeId,
          // listenMode / sampleRate / autoPunctuation / enableHapticFeedback are iOS-only in
          // 7.4.0, so they are deliberately left at their defaults here.
        ),
      );
      return true;
    } catch (_) {
      // ListenFailedException, or not initialised. Nothing else reports this, so it is reported
      // here — the old code swallowed it and left the screen waiting for a callback that on this
      // path never comes.
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {/* already stopped */}
  }

  @override
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {/* already stopped */}
  }
}

/// `Platform` throws on web; this app has no web target, but the guard keeps `isSupported` honest
/// if one is ever added.
const bool kIsWebLike = bool.fromEnvironment('dart.library.js_util');

/// Whether this build can do speech at all, without building an engine to ask. Android only, by
/// decision — a Windows till showing a microphone that cannot work is worse than no microphone.
bool get sttSupported => !kIsWebLike && Platform.isAndroid;
