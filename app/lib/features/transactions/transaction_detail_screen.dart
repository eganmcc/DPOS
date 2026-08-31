import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../order/online_orders_controller.dart';
import '../scanner/rongta_printer.dart';
import 'transaction_status.dart';

/// US3 (T038/T039) — transaction detail with the owner-gated void action.
///
/// The void never edits this sale: the server appends an OrderVoid, restores stock through a new
/// movement and writes a REVERSAL payment. This screen just re-reads the server's answer, where
/// the effective status derives to VOIDED.
class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.orderId, this.fromOnlineQueue = false});
  final String orderId;

  /// True only when opened from the online-orders (Pesanan) queue — that's where an
  /// active online order gets the "Print receipt" button that also moves it to
  /// history. Opened from History (default false) it behaves like any cash/QRIS
  /// detail: a plain app-bar reprint icon, no move.
  final bool fromOnlineQueue;

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  /// One idempotency key per void attempt on this screen: a retry after a dropped reply reuses it,
  /// so the server treats it as the same void and never restores stock twice (Constitution V).
  String? _clientVoidId;
  bool _voiding = false;
  bool _printing = false;

  /// An online order still in the active queue (not yet moved to history).
  bool _isActiveOnline(OrderResult o) =>
      o.isOnline && o.onlineStatus != 'COMPLETED' && o.onlineStatus != 'CANCELLED';

  Future<void> _confirmAndVoid(OrderResult order) async {
    final t = AppLocalizations.of(context)!;
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) => const _VoidReasonDialog(),
    );
    if (reason == null || !mounted) return; // dismissed = no void

    setState(() {
      _voiding = true;
      _clientVoidId ??= const Uuid().v4();
    });
    try {
      final json = await ref.read(apiClientProvider).voidOrder(
            order.id,
            clientVoidId: _clientVoidId!,
            reason: reason.isEmpty ? null : reason,
          );
      final voided = OrderResult.fromJson(json);
      if (!mounted) return;
      // Server state is canonical — refresh both the detail and the history list from it.
      ref.invalidate(transactionDetailProvider(order.id));
      final outletId = ref.read(sessionProvider)?.outletId;
      if (outletId != null) ref.invalidate(transactionsProvider(outletId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(voided.isVoided ? t.voidSuccess : t.voidFailed)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(code == 403 ? t.voidForbidden : t.voidFailed)),
      );
    } finally {
      if (mounted) setState(() => _voiding = false);
    }
  }

  /// Reprint this transaction's receipt — routes through the Rongta path when a
  /// Rongta is selected (kept-open socket + cash-drawer on cash), else printReceipt.
  Future<void> _printReceipt(OrderResult order) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(sessionProvider);
    final cat = session == null ? null : ref.read(catalogProvider(session.outletId)).valueOrNull;
    messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 1), content: Text('…')));
    final ok = await printReceiptSmart(order,
        businessName: cat?.merchantName, outletName: cat?.outletName);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(ok ? t.printerOk : t.printFailed)));
  }

  /// Online-order flow: print the receipt, mark the order fulfilled (→ history so it
  /// leaves the Pesanan queue), refresh both lists, and return to the queue.
  Future<void> _printAndComplete(OrderResult order) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final session = ref.read(sessionProvider);
    final outletId = session?.outletId;
    final cat = outletId == null ? null : ref.read(catalogProvider(outletId)).valueOrNull;

    setState(() => _printing = true);
    messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 1), content: Text('…')));
    final ok = await printReceiptSmart(order,
        businessName: cat?.merchantName, outletName: cat?.outletName);
    // Move it to history regardless of the print result — the cashier acted on it;
    // a failed print can be reprinted from history.
    try {
      await ref.read(apiClientProvider).completeOnlineOrder(order.id);
    } catch (_) {/* the queue poll reconciles */}
    if (!mounted) return;
    if (outletId != null) {
      ref.read(onlineOrdersProvider(outletId).notifier).refresh();
      ref.invalidate(transactionsProvider(outletId));
    }
    messenger.showSnackBar(SnackBar(content: Text(ok ? t.printerOk : t.printFailed)));
    navigator.pop(); // back to the Pesanan queue (order now gone from it)
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider)!;
    final async = ref.watch(transactionDetailProvider(widget.orderId));
    final loaded = async.valueOrNull;

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(t.transactionTitle),
        actions: [
          // Quick reprint app-bar icon — shown for every detail EXCEPT an active
          // online order opened from the Pesanan queue (that one uses the bottom
          // Print-receipt button). History views (including online) get the icon.
          if (loaded != null && !(widget.fromOnlineQueue && _isActiveOnline(loaded)))
            IconButton(
              tooltip: t.actionPrint,
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _printReceipt(loaded),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.errorHistory)),
        data: (order) => _Detail(order: order),
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (order) => (widget.fromOnlineQueue && _isActiveOnline(order))
            ? _PrintReceiptBar(busy: _printing, onPrint: () => _printAndComplete(order))
            : _VoidBar(
                order: order,
                isOwner: session.isOwner,
                busy: _voiding,
                onVoid: () => _confirmAndVoid(order),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.order});
  final OrderResult order;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final charges = order.payments.where((p) => !p.isReversal).toList();
    final reversals = order.payments.where((p) => p.isReversal).toList();
    final voidRecord = order.voids.isEmpty ? null : order.voids.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${shortOrderId(order.id)}',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(DateFormat('dd/MM/yyyy · HH:mm').format(order.createdAt),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            StatusChip(status: order.effectiveStatus),
          ],
        ),
        const SizedBox(height: 16),

        // The sale itself — immutable, shown exactly as it was recorded.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...order.lines.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text('${l.qty}× ${l.productNameSnapshot}')),
                          Text(formatRupiah(l.lineTotal)),
                        ],
                      ),
                    )),
                Divider(color: cs.outline, height: 24),
                _row(context, t.labelSubtotal, order.subtotal),
                if (order.discountTotal > 0) _row(context, t.labelDiscount, -order.discountTotal),
                _row(context, order.taxLabelSnapshot ?? t.labelTax, order.taxTotal),
                if (order.serviceChargeTotal > 0)
                  _row(context, t.labelService, order.serviceChargeTotal),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.labelTotal,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
                    Text(formatRupiah(order.grandTotal),
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Payments: the original charge stays as it was; a void adds a REVERSAL line beneath it.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.paymentTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final p in charges) ...[
                  _row(context, p.method, p.tendered ?? p.amount, muted: true),
                  if (p.change != null) _row(context, t.labelChange, p.change!, muted: true),
                ],
                for (final r in reversals)
                  _row(
                    context,
                    '${t.paymentReversal} · ${r.method}',
                    -r.amount,
                    muted: true,
                    highlight: true,
                  ),
              ],
            ),
          ),
        ),

        // The void record itself — who, when, why.
        if (voidRecord != null) ...[
          const SizedBox(height: 12),
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.block, size: 18, color: cs.onErrorContainer),
                      const SizedBox(width: 8),
                      Text(t.voidedHeader,
                          style: TextStyle(
                              color: cs.onErrorContainer, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('dd/MM/yyyy · HH:mm').format(voidRecord.createdAt),
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                  ),
                  if ((voidRecord.reason ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${t.voidReasonLabel}: ${voidRecord.reason}',
                          style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
                    ),
                  const SizedBox(height: 6),
                  Text(t.voidImmutableNote,
                      style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String label, int amount,
      {bool muted = false, bool highlight = false}) {
    final cs = Theme.of(context).colorScheme;
    final style = highlight
        ? TextStyle(color: cs.error, fontSize: 13, fontWeight: FontWeight.w600)
        : (muted ? TextStyle(color: cs.onSurfaceVariant, fontSize: 13) : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(formatRupiah(amount), style: style)],
      ),
    );
  }
}

/// Bottom action bar. The void button exists only for an OWNER on a still-live sale — a cashier
/// sees why it is unavailable instead (the server refuses them regardless).
class _VoidBar extends StatelessWidget {
  const _VoidBar({
    required this.order,
    required this.isOwner,
    required this.busy,
    required this.onVoid,
  });

  final OrderResult order;
  final bool isOwner;
  final bool busy;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    if (!order.canBeVoided) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: isOwner
            ? SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.block, size: 18),
                  label: Text(t.actionVoidSale),
                  onPressed: busy ? null : onVoid,
                ),
              )
            : Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.voidOwnerOnly,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bottom action for an online order still in the queue: print the receipt, which
/// also marks it fulfilled and moves it to history.
class _PrintReceiptBar extends StatelessWidget {
  const _PrintReceiptBar({required this.busy, required this.onPrint});
  final bool busy;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: busy
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_outlined, size: 18),
            label: Text(t.actionPrint),
            onPressed: busy ? null : onPrint,
          ),
        ),
      ),
    );
  }
}

/// Confirmation + optional reason. Returns the reason (possibly empty) on confirm, null on cancel.
class _VoidReasonDialog extends StatefulWidget {
  const _VoidReasonDialog();

  @override
  State<_VoidReasonDialog> createState() => _VoidReasonDialogState();
}

class _VoidReasonDialogState extends State<_VoidReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(t.voidConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.voidConfirmBody),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: t.voidReasonLabel, isDense: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: Text(t.actionVoidConfirm),
        ),
      ],
    );
  }
}
