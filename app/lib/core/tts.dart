import 'package:flutter_tts/flutter_tts.dart';
import 'terbilang.dart';

/// A single app-wide TTS engine. It deliberately does NOT live on any widget, so
/// navigating away (e.g. to the receipt) can't dispose/stop it mid-sentence.
final FlutterTts _tts = FlutterTts();
bool _init = false;

/// Pick a concrete engine once. Some devices leave the default TTS engine unset,
/// which stops speech from ever starting — so prefer Google's engine when it's
/// installed.
Future<void> _ensureInit() async {
  if (_init) return;
  _init = true;
  try {
    final engines = await _tts.getEngines;
    if (engines is List && engines.contains('com.google.android.tts')) {
      await _tts.setEngine('com.google.android.tts');
    }
  } catch (_) {
    /* keep the platform default */
  }
}

/// Speak the received amount in Indonesian: "diterima {terbilang} rupiah".
/// Fire-and-forget — returns as soon as the utterance is queued so the UI can
/// move on while it plays. Silent (never throws) where TTS is unavailable.
Future<void> announceReceived(int amount) async {
  final text = 'diterima ${terbilang(amount)} rupiah';
  try {
    await _ensureInit();
    // Use the Indonesian voice when the device has it; otherwise still speak
    // (with the default voice) rather than going silent.
    final available = await _tts.isLanguageAvailable('id-ID');
    if (available == true || available == 1) {
      await _tts.setLanguage('id-ID');
    }
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  } catch (_) {
    /* no usable TTS engine on this device */
  }
}
