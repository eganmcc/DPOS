import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../order/order_screen.dart';
import '../order/online_orders_controller.dart';
import 'dpos_printer.dart';
import 'scanner_screen.dart';

/// Chooses the home surface: the barcode ScannerScreen for grocery outlets
/// (auto when a DPOSP printer is paired, or forced via the Settings toggle),
/// otherwise the normal OrderScreen. Defaults to OrderScreen while things load
/// (OrderScreen renders its own catalog loading/error).
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider)!;
    final catalogAsync = ref.watch(catalogProvider(session.outletId));
    final mode = ref.watch(scannerModeSettingProvider);

    return catalogAsync.maybeWhen(
      data: (catalog) {
        // F&B: keep the online-order queue alive for the whole session so the
        // badge + TTS work regardless of which screen is on top, and the demo
        // timer stops on logout (this provider is disposed with HomeGate).
        if (catalog.isFnb) ref.watch(onlineOrdersProvider(session.outletId));
        if (mode == 'off' || !catalog.isGrocery) return const OrderScreen();
        if (mode == 'on') return const ScannerScreen();
        // 'auto': scanner only when the DPOSP printer is actually paired.
        return ref.watch(dposPrinterProvider).maybeWhen(
              data: (present) => present ? const ScannerScreen() : const OrderScreen(),
              orElse: () => const OrderScreen(),
            );
      },
      orElse: () => const OrderScreen(),
    );
  }
}
