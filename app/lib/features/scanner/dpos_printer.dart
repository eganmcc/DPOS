import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

const kPrinterName = 'DPOSP';

/// The MAC of the paired "DPOSP" printer, or null. Requests BLUETOOTH_CONNECT
/// first. Any failure (permission denied, BT off, no device) resolves to null so
/// callers just skip printing / the scanner gate falls back to the order screen.
Future<String?> findDposPrinterMac() async {
  try {
    final status = await Permission.bluetoothConnect.request();
    if (!status.isGranted) return null;
    if (!await PrintBluetoothThermal.bluetoothEnabled) return null;
    final paired = await PrintBluetoothThermal.pairedBluetooths;
    // Match leniently: the printer may be paired as "DPOSP", "DPOSP-1234", etc.
    for (final d in paired) {
      if (d.name.trim().toUpperCase().contains(kPrinterName)) return d.macAdress;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Names of all paired Bluetooth devices — for the Settings printer diagnostic.
Future<List<String>> pairedBluetoothNames() async {
  try {
    if (!(await Permission.bluetoothConnect.request()).isGranted) return const [];
    return (await PrintBluetoothThermal.pairedBluetooths).map((d) => d.name).toList();
  } catch (_) {
    return const [];
  }
}

/// True when a paired Bluetooth printer named "DPOSP" is present. Drives the
/// scanner-mode gate (grocery + this) and whether checkout auto-prints.
final dposPrinterProvider = FutureProvider<bool>((ref) async {
  return (await findDposPrinterMac()) != null;
});
