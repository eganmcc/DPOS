import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Name fragments of typical thermal receipt printers — used to auto-pick one
/// when the cashier hasn't explicitly selected a printer. Note: Android/the BT
/// plugin reports the *factory* device name (e.g. "RPP02N"), not the alias the
/// user renamed it to, so we can't rely on "DPOSP".
const _printerNameHints = ['DPOS', 'RPP', 'POS', 'PRINT', 'THERMAL', 'BLE'];
const _selectedMacKey = 'printerMac';

class BtPrinter {
  final String name;
  final String mac;
  const BtPrinter(this.name, this.mac);
}

Future<List<BtPrinter>> pairedPrinters() async {
  try {
    if (!(await Permission.bluetoothConnect.request()).isGranted) return const [];
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((d) => BtPrinter(d.name, d.macAdress)).toList();
  } catch (_) {
    return const [];
  }
}

Future<String?> selectedPrinterMac() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_selectedMacKey);
}

Future<void> setSelectedPrinterMac(String? mac) async {
  final p = await SharedPreferences.getInstance();
  if (mac == null) {
    await p.remove(_selectedMacKey);
  } else {
    await p.setString(_selectedMacKey, mac);
  }
}

/// The MAC of the receipt printer to use: the explicitly-selected one if it's
/// still paired, otherwise the first paired device whose (factory) name looks
/// like a thermal printer. Null when nothing suitable is paired.
Future<String?> receiptPrinterMac() async {
  final printers = await pairedPrinters();
  if (printers.isEmpty) return null;
  final sel = await selectedPrinterMac();
  if (sel != null && printers.any((d) => d.mac == sel)) return sel;
  for (final d in printers) {
    final n = d.name.toUpperCase();
    if (_printerNameHints.any(n.contains)) return d.mac;
  }
  return null;
}

/// True when a usable receipt printer is available (drives the scanner-mode gate
/// and whether checkout auto-prints).
final dposPrinterProvider = FutureProvider<bool>((ref) async {
  return (await receiptPrinterMac()) != null;
});

/// Selected printer MAC as a reactive setting (mirrors shared_preferences).
class SelectedPrinterNotifier extends StateNotifier<String?> {
  SelectedPrinterNotifier() : super(null) {
    selectedPrinterMac().then((v) => state = v);
  }
  Future<void> select(String? mac) async {
    state = mac;
    await setSelectedPrinterMac(mac);
  }
}

final selectedPrinterProvider =
    StateNotifierProvider<SelectedPrinterNotifier, String?>((ref) => SelectedPrinterNotifier());
