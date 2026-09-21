import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything about a listen session that is worth turning a dial on, and nothing that isn't.
///
/// Verified against the installed `speech_to_text 7.4.0` /
/// `speech_to_text_platform_interface 2.4.0` rather than the docs. That check matters: in
/// `SpeechListenOptions`, `listenMode`, `sampleRate`, `autoPunctuation` and `enableHapticFeedback`
/// are all marked *"currently only supported on iOS"*. The field guide this feature came from
/// passes `ListenMode.dictation`; on Android it does nothing at all, so it is not offered here.
///
/// The three `android*` flags below are `SpeechConfigOption`s passed to `initialize()`, not to
/// `listen()` — changing one requires re-initialising the engine.
class SttOptions {
  /// null = use whatever the device calls Indonesian (see SttEngine.pickIndonesian).
  final String? localeId;

  /// Silence that ends the session. NOTE: in 7.4.0 this timer starts at `listen()`, NOT at the
  /// first word — set it too low and the session dies before the cashier opens their mouth.
  final int pauseForSeconds;

  /// Hard cap on one session.
  final int listenForSeconds;

  /// Stream partials as they are recognised. Off = only the final result arrives.
  final bool partialResults;

  /// End the session on a permanent error instead of letting it linger.
  final bool cancelOnError;

  /// Force on-device recognition. The listen FAILS outright if the device cannot — which is the
  /// point: it answers "does this phone work without a network" unambiguously.
  final bool onDevice;

  /// Keep listening until the user presses stop.
  ///
  /// The plugin has no such mode: a session always ends on `pauseFor` silence or the `listenFor`
  /// cap. So this restarts it each time it ends, and each utterance lands as its own result. Both
  /// halves matter — without it a cashier gets one sentence per tap.
  final bool continuous;

  /// How long the plugin waits for a final result (its own default is 2000 ms). Directly upstream
  /// of the late-duplicate problem: raise it and late finals get later.
  final int finalTimeoutMs;

  /// `androidNoBluetooth` — stops the plugin considering Bluetooth for audio routing. This app
  /// pairs a Bluetooth thermal printer, so it is worth being able to take Bluetooth out of the
  /// picture and see whether recognition changes.
  final bool androidNoBluetooth;

  /// `androidIntentLookup` — the documented workaround for Android builds that do not properly
  /// define the recognition intent. The first thing to try on an OEM ROM that reports no recognizer.
  final bool androidIntentLookup;

  /// `androidAlwaysUseStop` — forces stop() instead of destroying the recognizer (an SDK 29 bug).
  final bool androidAlwaysUseStop;

  /// The plugin's own logging, which goes to logcat under the tag `SpeechToText`.
  ///
  /// On by default here BECAUSE this screen is a bench: when a session dies for a reason the Dart
  /// side never hears about, the plugin's own trace is the only record of what Android said.
  final bool debugLogging;

  const SttOptions({
    this.localeId,
    this.pauseForSeconds = 3,
    this.listenForSeconds = 30,
    this.partialResults = true,
    this.cancelOnError = true,
    this.onDevice = false,
    this.continuous = false,
    this.finalTimeoutMs = 2000,
    this.androidNoBluetooth = false,
    this.androidIntentLookup = false,
    this.androidAlwaysUseStop = false,
    this.debugLogging = true,
  });

  /// Below ~2s the session ends before the speaker starts, because of the `pauseFor` timing above.
  static const int minPauseSeconds = 2;
  static const int maxPauseSeconds = 15;
  static const int minListenSeconds = 5;
  static const int maxListenSeconds = 120;

  SttOptions copyWith({
    String? localeId,
    bool clearLocale = false,
    int? pauseForSeconds,
    int? listenForSeconds,
    bool? partialResults,
    bool? cancelOnError,
    bool? onDevice,
    bool? continuous,
    int? finalTimeoutMs,
    bool? androidNoBluetooth,
    bool? androidIntentLookup,
    bool? androidAlwaysUseStop,
    bool? debugLogging,
  }) =>
      SttOptions(
        localeId: clearLocale ? null : (localeId ?? this.localeId),
        pauseForSeconds: (pauseForSeconds ?? this.pauseForSeconds)
            .clamp(minPauseSeconds, maxPauseSeconds),
        listenForSeconds: (listenForSeconds ?? this.listenForSeconds)
            .clamp(minListenSeconds, maxListenSeconds),
        partialResults: partialResults ?? this.partialResults,
        cancelOnError: cancelOnError ?? this.cancelOnError,
        onDevice: onDevice ?? this.onDevice,
        continuous: continuous ?? this.continuous,
        finalTimeoutMs: (finalTimeoutMs ?? this.finalTimeoutMs).clamp(500, 10000),
        androidNoBluetooth: androidNoBluetooth ?? this.androidNoBluetooth,
        androidIntentLookup: androidIntentLookup ?? this.androidIntentLookup,
        androidAlwaysUseStop: androidAlwaysUseStop ?? this.androidAlwaysUseStop,
        debugLogging: debugLogging ?? this.debugLogging,
      );

  Map<String, dynamic> toJson() => {
        if (localeId != null) 'localeId': localeId,
        'pauseForSeconds': pauseForSeconds,
        'listenForSeconds': listenForSeconds,
        'partialResults': partialResults,
        'cancelOnError': cancelOnError,
        'onDevice': onDevice,
        'continuous': continuous,
        'finalTimeoutMs': finalTimeoutMs,
        'androidNoBluetooth': androidNoBluetooth,
        'androidIntentLookup': androidIntentLookup,
        'androidAlwaysUseStop': androidAlwaysUseStop,
        'debugLogging': debugLogging,
      };

  /// Tolerant: a stored value from an older build must never stop the lab opening.
  factory SttOptions.fromJson(Map<String, dynamic> j) {
    int i(String k, int fallback) => j[k] is int ? j[k] as int : fallback;
    bool b(String k, bool fallback) => j[k] is bool ? j[k] as bool : fallback;
    return const SttOptions().copyWith(
      localeId: j['localeId'] as String?,
      pauseForSeconds: i('pauseForSeconds', 3),
      listenForSeconds: i('listenForSeconds', 30),
      partialResults: b('partialResults', true),
      cancelOnError: b('cancelOnError', true),
      onDevice: b('onDevice', false),
      continuous: b('continuous', false),
      finalTimeoutMs: i('finalTimeoutMs', 2000),
      androidNoBluetooth: b('androidNoBluetooth', false),
      androidIntentLookup: b('androidIntentLookup', false),
      androidAlwaysUseStop: b('androidAlwaysUseStop', false),
      debugLogging: b('debugLogging', true),
    );
  }

  /// One line per setting, for the "copy diagnostics" clipboard dump.
  String describe() => toJson().entries.map((e) => '  ${e.key}: ${e.value}').join('\n');
}

/// Per-device, persisted — following `ScannerModeNotifier` in `core/settings.dart`: load from the
/// constructor, validate what comes back, set state before writing.
class SttOptionsNotifier extends StateNotifier<SttOptions> {
  SttOptionsNotifier() : super(const SttOptions()) {
    _load();
  }

  static const _key = 'sttOptions';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return;
    try {
      state = SttOptions.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt blob must not block the screen; the defaults are perfectly usable.
    }
  }

  Future<void> set(SttOptions next) async {
    state = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(next.toJson()));
  }
}

final sttOptionsProvider =
    StateNotifierProvider<SttOptionsNotifier, SttOptions>((ref) => SttOptionsNotifier());
