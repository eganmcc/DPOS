import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import 'dpos_printer.dart' show BtPrinter, pairedPrinters, receiptPrinterMac;
import 'receipt_printer.dart' show printReceipt;

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

/// Factory-name fragments that identify a Rongta printer (RP58_BU etc.).
const _rongtaNameHints = ['RP58', 'RONGTA'];

/// True when the selected/auto-picked receipt printer is a Rongta — used to route
/// checkout receipts down this (kept-open, settle-delayed) path instead of the
/// default `printBytesNative` flow. Never throws.
Future<bool> isRongtaSelected() async {
  try {
    final mac = await receiptPrinterMac();
    if (mac == null) return false;
    final printers = await pairedPrinters();
    final chosen = printers.firstWhere((p) => p.mac == mac, orElse: () => const BtPrinter('', ''));
    final n = chosen.name.toUpperCase();
    return _rongtaNameHints.any(n.contains);
  } catch (_) {
    return false;
  }
}

/// Dispatch a receipt to the right printer path: the Rongta path when a Rongta is
/// selected, otherwise the existing (untouched) `printReceipt` flow. Returns whether
/// it printed (used by the reprint button); never throws.
Future<bool> printReceiptSmart(
  OrderResult order, {
  String? businessName,
  String? outletName,
}) async {
  if (await isRongtaSelected()) {
    return printReceiptRongta(order, businessName: businessName, outletName: outletName);
  }
  return printReceipt(order, businessName: businessName, outletName: outletName);
}

String _methodLabel(String m) =>
    m == 'CASH' ? 'Tunai' : m == 'QRIS_SIMULATED' ? 'QRIS' : m == 'ONLINE' ? 'Online' : m;

/// Print a settled order's receipt via the Rongta path. Mirrors the layout of the
/// working `printReceipt`, but sends through `printBytesRongta` (kept-open socket +
/// settle delay) and — **only for a CASH transaction** — appends the cash-drawer
/// pulse so the register opens after printing. Returns false / never throws.
Future<bool> printReceiptRongta(
  OrderResult order, {
  String? businessName,
  String? outletName,
}) async {
  try {
    final mac = await receiptPrinterMac();
    if (mac == null) return false;

    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    final b = <int>[];

    b.addAll(g.text(businessName ?? 'DPOS',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2)));
    if (outletName != null && outletName.isNotEmpty) {
      b.addAll(g.text(outletName, styles: const PosStyles(align: PosAlign.center)));
    }
    b.addAll(g.text(
        '#${order.id.substring(0, 8)}   ${DateFormat('dd/MM/yy HH:mm').format(order.createdAt)}',
        styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.hr());

    for (final l in order.lines) {
      b.addAll(g.row([
        PosColumn(text: '${l.qty}x ${l.productNameSnapshot}', width: 8),
        PosColumn(
            text: formatRupiah(l.lineTotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    b.addAll(g.hr());

    void row(String label, int amount) => b.addAll(g.row([
          PosColumn(text: label, width: 7),
          PosColumn(
              text: formatRupiah(amount), width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]));

    row('Subtotal', order.subtotal);
    if (order.discountTotal > 0) row('Diskon', -order.discountTotal);
    if (order.taxTotal > 0) row(order.taxLabelSnapshot ?? 'Pajak', order.taxTotal);
    if (order.serviceChargeTotal > 0) row('Layanan', order.serviceChargeTotal);
    b.addAll(g.row([
      PosColumn(
          text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: formatRupiah(order.grandTotal),
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2, align: PosAlign.right)),
    ]));
    b.addAll(g.hr());

    final p = order.payments.isNotEmpty ? order.payments.first : null;
    if (p != null) {
      row(_methodLabel(p.method), p.amount);
      if ((p.change ?? 0) > 0) row('Kembalian', p.change!);
    }
    b.addAll(g.text('LUNAS', styles: const PosStyles(align: PosAlign.center, bold: true)));
    b.addAll(g.text('Terima kasih', styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.feed(3)); // no cut — RP58 has no auto-cutter; feed past the tear bar

    // Open the cash drawer ONLY for a cash transaction.
    if (p?.method == 'CASH') b.addAll(kCashDrawerKick);

    final status = await printBytesRongta(mac, b);
    return status.startsWith('OK');
  } catch (_) {
    return false;
  }
}
