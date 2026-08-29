import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dpos_printer.dart' show receiptPrinterMac;

/// SEPARATE, diagnostic print path for the Rongta RP58 — isolated from the working
/// `printBytesNative`/`printBytes` flow (RPP02N + receipt/checkout). The native
/// `printBytesRongta` returns a status STRING (HyperOS hides app logcat on release
/// builds), so the caller can show it in the UI. Nothing here touches the existing path.
const _channel = MethodChannel('dpos/printer');

/// ESC/POS "generate pulse" (ESC p m t1 t2) to kick the cash drawer wired to the
/// printer's RJ11 port. Drawers sit on connector pin 2 (m=0) or pin 5 (m=1); only
/// the wired pin responds, so we send both. Append to the end of a print job so the
/// drawer opens right after the receipt prints.
const List<int> kCashDrawerKick = [
  0x1B, 0x70, 0x00, 0x19, 0xFA, // ESC p 0 25 250 — pin 2
  0x1B, 0x70, 0x01, 0x19, 0xFA, // ESC p 1 25 250 — pin 5
];

/// Send raw bytes to [mac] via the Rongta RP58 native path. Returns the native
/// status string ("OK via …" / "FAIL: …"). Never throws.
Future<String> printBytesRongta(String mac, List<int> bytes) async {
  try {
    final s = await _channel.invokeMethod<String>('printBytesRongta', {
      'mac': mac,
      'bytes': Uint8List.fromList(bytes),
    });
    return s ?? 'FAIL: null result';
  } catch (e) {
    return 'FAIL: $e';
  }
}

/// Send raw bytes to [mac] via the RP58 **BLE/GATT** native path. Returns the native
/// status string ("BLE OK: …" / "FAIL(BLE): …"). Never throws.
Future<String> printBytesRongtaBle(String mac, List<int> bytes) async {
  try {
    final s = await _channel.invokeMethod<String>('printBytesRongtaBle', {
      'mac': mac,
      'bytes': Uint8List.fromList(bytes),
    });
    return s ?? 'FAIL(BLE): null result';
  } catch (e) {
    return 'FAIL(BLE): $e';
  }
}

/// Diagnostic test slip over BLE — same minimal raw payload as the Classic test.
/// Reports which GATT characteristic it wrote to (or dumps services if none writable).
Future<String> printTestRongtaBle() async {
  try {
    final mac = await receiptPrinterMac();
    if (mac == null) return 'FAIL(BLE): no printer selected';
    final b = <int>[];
    b.addAll([0x1B, 0x40]); // ESC @ initialize
    b.addAll('DPOS - Rongta RP58 BLE test\n'.codeUnits);
    b.addAll('${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}\n'.codeUnits);
    b.addAll('\n\n\n\n'.codeUnits);
    return await printBytesRongtaBle(mac, b);
  } catch (e) {
    return 'FAIL(BLE): $e';
  }
}

/// Diagnostic test slip via the RP58 path. Sends a **minimal raw ESC/POS** payload
/// (ESC @ init + plain ASCII + line feeds) — deliberately bypassing esc_pos_utils —
/// to isolate whether the issue is the connection/transmission or the library's
/// command bytes. Returns the native status string for the caller to display.
Future<String> printTestRongta() async {
  try {
    final mac = await receiptPrinterMac();
    if (mac == null) return 'FAIL: no printer selected';
    final b = <int>[];
    b.addAll([0x1B, 0x40]); // ESC @  — initialize printer
    b.addAll('DPOS - Rongta RP58 test\n'.codeUnits);
    b.addAll('${DateFormat('dd/MM/yy HH:mm').format(DateTime.now())}\n'.codeUnits);
    b.addAll('\n\n\n\n'.codeUnits); // feed past the tear bar (no cut)
    b.addAll(kCashDrawerKick); // open the cash register after printing
    return await printBytesRongta(mac, b);
  } catch (e) {
    return 'FAIL: $e';
  }
}
