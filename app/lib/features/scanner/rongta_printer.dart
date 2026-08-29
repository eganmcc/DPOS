import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dpos_printer.dart' show receiptPrinterMac;

/// SEPARATE print path for the Rongta RP58 — deliberately isolated from the
/// working `printBytesNative`/`printBytes` flow (used by the RPP02N and the
/// receipt/checkout code). It calls the native `printBytesRongta` method, which
/// connects via SDP-resolved sockets only (no channel-1 reflection), writes in
/// chunks, and drains before closing. Nothing here touches the existing path.
const _channel = MethodChannel('dpos/printer');

/// Send raw ESC/POS bytes to [mac] over the Rongta RP58 native path. Never throws.
Future<bool> printBytesRongta(String mac, List<int> bytes) async {
  try {
    final ok = await _channel.invokeMethod<bool>('printBytesRongta', {
      'mac': mac,
      'bytes': Uint8List.fromList(bytes),
    });
    return ok ?? false;
  } catch (_) {
    return false;
  }
}

/// Print a short test slip via the Rongta RP58 path (Settings diagnostic).
/// Uses the same selected/auto-picked printer MAC as the normal flow, but the
/// dedicated native connect+write. No `cut()` — the RP58 typically has no
/// auto-cutter, so extra feed clears the tear bar instead.
Future<bool> printTestRongta() async {
  try {
    final mac = await receiptPrinterMac();
    if (mac == null) return false;
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    final b = <int>[];
    b.addAll(g.text('DPOS',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)));
    b.addAll(g.text('Rongta RP58 test', styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.text(DateFormat('dd/MM/yy HH:mm').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.feed(3));
    return await printBytesRongta(mac, b);
  } catch (_) {
    return false;
  }
}
