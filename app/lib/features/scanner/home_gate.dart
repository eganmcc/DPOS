import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/attendance_actions.dart';
import '../../core/settings.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../calculator/nota_calculator_screen.dart';
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

  /// Offer to clock in once per session, after the first frame. Driven from build
  /// rather than initState because the decision depends on the catalog: a UMI
  /// merchant is one person, so there is nobody to track and we don't ask at all.
  void _maybePromptClockIn() {
    if (_askedClockIn) return;
    _askedClockIn = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) promptClockInOnLogin(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final catalogAsync = ref.watch(catalogProvider(session.outletId));

    return catalogAsync.when(
      data: (catalog) {
        if (catalog.isFnb) ref.watch(onlineOrdersProvider(session.outletId));
        if (!catalog.isUmi) _maybePromptClockIn();
        // A merchant with no catalog sells on the keypad — for every role, since the owner of a
        // one-person kiosk is also its cashier. Checked first so it wins over the owner→Reports
        // rule below. Reports, Riwayat and Settings stay on its app bar.
        if (catalog.isCalculatorOnly) return const NotaCalculatorScreen();
        // A UMI operator's next action is always ringing up a customer, so land on
        // the till. Reports stays one tap away via the POS app bar's insights icon.
        if (session.isOwnerOrManager && !catalog.isUmi) return const ReportsScreen();
        return const PosHome();
      },
      // Neutral while the catalog resolves. Falling through to PosHome here, as this used to,
      // flashed an empty product grid at a calculator merchant on every cold start.
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // No catalog at all — not even the offline cache catalogProvider falls back to. Keep the
      // old behaviour rather than a spinner that would never end.
      error: (_, __) => const PosHome(),
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
