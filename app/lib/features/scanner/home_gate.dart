import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/attendance_actions.dart';
import '../../core/settings.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../order/order_screen.dart';
import '../order/online_orders_controller.dart';
import '../reports/reports_screen.dart';
import 'dpos_printer.dart';
import 'scanner_screen.dart';

/// Chooses the home surface by role: owner/manager land on the Reports screen;
/// cashiers land on the cashier POS ([PosHome]). The online-order queue is kept
/// alive here for the whole authenticated session (badge + TTS), regardless of
/// which surface is on top, and is disposed on logout with this widget.
class HomeGate extends ConsumerStatefulWidget {
  const HomeGate({super.key});

  @override
  ConsumerState<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends ConsumerState<HomeGate> {
  bool _askedClockIn = false;

  @override
  void initState() {
    super.initState();
    // Offer to clock in once per session, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_askedClockIn || !mounted) return;
      _askedClockIn = true;
      promptClockInOnLogin(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final catalogAsync = ref.watch(catalogProvider(session.outletId));

    return catalogAsync.maybeWhen(
      data: (catalog) {
        if (catalog.isFnb) ref.watch(onlineOrdersProvider(session.outletId));
        if (session.isOwnerOrManager) return const ReportsScreen();
        return const PosHome();
      },
      orElse: () => const PosHome(),
    );
  }
}

/// The cashier POS surface: the barcode ScannerScreen for grocery outlets (auto
/// when a DPOSP printer is paired, or forced via the Settings toggle), otherwise
/// the normal OrderScreen. Owner/manager reach this by tapping "Open cashier" on
/// the Reports screen.
class PosHome extends ConsumerWidget {
  const PosHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider)!;
    final catalogAsync = ref.watch(catalogProvider(session.outletId));
    final mode = ref.watch(scannerModeSettingProvider);

    return catalogAsync.maybeWhen(
      data: (catalog) {
        if (catalog.isFnb) ref.watch(onlineOrdersProvider(session.outletId));
        if (mode == 'off' || !catalog.isGrocery) return const OrderScreen();
        if (mode == 'on') return const ScannerScreen();
        return ref.watch(dposPrinterProvider).maybeWhen(
              data: (present) => present ? const ScannerScreen() : const OrderScreen(),
              orElse: () => const OrderScreen(),
            );
      },
      orElse: () => const OrderScreen(),
    );
  }
}
