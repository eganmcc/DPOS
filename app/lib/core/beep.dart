import 'package:flutter/services.dart';

// Native ToneGenerator beep (see MainActivity.kt) — instant and reliable for
// rapid scans, unlike the asset-playback path which queued/lagged on some phones.
const _channel = MethodChannel('dpos/printer');

/// Pre-create the tone generator so the first scan beeps immediately.
Future<void> warmUpBeep() async {
  try {
    await _channel.invokeMethod('warmupBeep');
  } catch (_) {}
}

Future<void> beep() async {
  try {
    await _channel.invokeMethod('beep');
  } catch (_) {}
}
