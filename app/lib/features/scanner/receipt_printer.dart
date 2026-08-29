import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import 'dpos_printer.dart';

/// Print a settled order's receipt to the paired "DPOSP" 58mm thermal printer.
/// Returns false (never throws) when no DPOSP is paired or printing fails, so
/// checkout is never blocked by the printer.
Future<bool> printReceipt(
  OrderResult order, {
  String? businessName,
  String? outletName,
}) async {
  try {
    final mac = await findDposPrinterMac();
    if (mac == null) return false;
    if (!await _ensureConnected(mac)) return false;

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
    b.addAll(g.text('#${order.id.substring(0, 8)}   ${DateFormat('dd/MM/yy HH:mm').format(order.createdAt)}',
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
          PosColumn(text: formatRupiah(amount), width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]));

    row('Subtotal', order.subtotal);
    if (order.discountTotal > 0) row('Diskon', -order.discountTotal);
    if (order.taxTotal > 0) row(order.taxLabelSnapshot ?? 'Pajak', order.taxTotal);
    if (order.serviceChargeTotal > 0) row('Layanan', order.serviceChargeTotal);
    b.addAll(g.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: formatRupiah(order.grandTotal),
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2, align: PosAlign.right)),
    ]));
    b.addAll(g.hr());

    final p = order.payments.isNotEmpty ? order.payments.first : null;
    if (p != null) {
      row(_method(p.method), p.amount);
      if ((p.change ?? 0) > 0) row('Kembalian', p.change!);
    }
    b.addAll(g.text('LUNAS', styles: const PosStyles(align: PosAlign.center, bold: true)));
    b.addAll(g.text('Terima kasih', styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.feed(2));
    b.addAll(g.cut());

    return await PrintBluetoothThermal.writeBytes(b);
  } catch (_) {
    return false;
  }
}

String _method(String m) =>
    m == 'CASH' ? 'Tunai' : m == 'QRIS_SIMULATED' ? 'QRIS' : m;

/// Connect to the printer, retrying — SPP thermal printers often fail the first
/// connect attempt even when powered on and paired.
Future<bool> _ensureConnected(String mac) async {
  if (await PrintBluetoothThermal.connectionStatus) return true;
  for (var attempt = 0; attempt < 4; attempt++) {
    if (await PrintBluetoothThermal.connect(macPrinterAddress: mac)) return true;
    await Future.delayed(const Duration(milliseconds: 700));
  }
  return false;
}

/// Print a short test slip to confirm the DPOSP connection (Settings diagnostic).
Future<bool> printTest() async {
  try {
    final mac = await findDposPrinterMac();
    if (mac == null) return false;
    if (!await _ensureConnected(mac)) return false;
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    final b = <int>[];
    b.addAll(g.text('DPOS',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)));
    b.addAll(g.text('Printer test OK', styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.text(DateFormat('dd/MM/yy HH:mm').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center)));
    b.addAll(g.feed(2));
    b.addAll(g.cut());
    return await PrintBluetoothThermal.writeBytes(b);
  } catch (_) {
    return false;
  }
}
