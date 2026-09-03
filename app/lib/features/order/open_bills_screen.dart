import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../payment/checkout_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import 'cart.dart';
import 'online_orders_controller.dart';
import 'vendor_icon.dart';

/// "Pesanan": incoming online-delivery orders (F&B) plus open bills
/// (confirm-now-pay-later). Online orders arrive with a NEW badge — tap Terima to
/// acknowledge; open bills are tapped to settle.
class OpenBillsScreen extends ConsumerStatefulWidget {
  const OpenBillsScreen({super.key});

  @override
  ConsumerState<OpenBillsScreen> createState() => _OpenBillsScreenState();
}

class _OpenBillsScreenState extends ConsumerState<OpenBillsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final outletId = ref.watch(sessionProvider)!.outletId;
    final isFnb = ref.watch(catalogProvider(outletId)).valueOrNull?.isFnb ?? false;
    final online =
        isFnb ? ref.watch(onlineOrdersProvider(outletId)) : const OnlineOrdersState(loading: false);
    final billsAsync = ref.watch(openBillsProvider(outletId));

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.openBillsTitle)),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.errorHistory)),
        data: (bills) {
          final onlineOrders = online.orders;
          if (bills.isEmpty && onlineOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 44, color: cs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(t.emptyOpenBills, style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }
          final filteredBills = _q.isEmpty
              ? bills
              : bills
                  .where((b) => (b.tableLabel ?? '').toUpperCase().contains(_q.toUpperCase()))
                  .toList();
          final showBillsHeader = onlineOrders.isNotEmpty && bills.isNotEmpty;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(openBillsProvider(outletId));
              if (isFnb) await ref.read(onlineOrdersProvider(outletId).notifier).refresh();
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                if (onlineOrders.isNotEmpty) ...[
                  _header(t.onlineOrdersTitle, cs),
                  for (final o in onlineOrders) _onlineTile(o, outletId, t, cs),
                ],
                if (bills.isNotEmpty) ...[
                  if (showBillsHeader) _header(t.openBillsTitle, cs),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                    child: TextField(
                      inputFormatters: [UpperCaseTextInputFormatter()],
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: t.searchTable,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  for (final b in filteredBills) _billTile(b, t, cs),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(String label, ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: cs.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
      );

  Widget _onlineTile(OrderResult o, String outletId, AppLocalizations t, ColorScheme cs) {
    final isNew = o.isUnprocessed;
    final count = o.lines.fold<int>(0, (s, l) => s + (num.tryParse(l.qty)?.toInt() ?? 0));
    final customer = (o.customerName?.isNotEmpty ?? false) ? '${o.customerName} · ' : '';
    return ListTile(
      leading: vendorIcon(o.channel),
      title: Row(
        children: [
          Flexible(
            child: Text('#${o.externalOrderRef ?? o.id.substring(0, 4)} · ${vendorName(o.channel)}',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (isNew)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(6)),
              child: Text(t.onlineOrderNew,
                  style: TextStyle(color: cs.onError, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      subtitle: Text(
          '$customer${t.itemsLabel(count)} · ${DateFormat('HH:mm').format(o.createdAt)} · ${formatRupiah(o.grandTotal)}'),
      trailing: isNew
          ? FilledButton.tonal(
              onPressed: () => ref.read(onlineOrdersProvider(outletId).notifier).accept(o.id),
              child: Text(t.onlineOrderAccept),
            )
          : null,
      // Details are viewable at any stage — NEW included (the Terima button keeps
      // its own tap for accepting).
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(orderId: o.id, fromOnlineQueue: true)),
      ),
    );
  }

  Widget _billTile(OrderResult b, AppLocalizations t, ColorScheme cs) {
    final count = b.lines.fold<int>(0, (s, l) => s + (num.tryParse(l.qty)?.toInt() ?? 0));
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primary,
        child: Text(
          b.tableLabel?.isNotEmpty == true ? b.tableLabel! : 'TA',
          style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      title: Text(
        b.tableLabel != null && b.tableLabel!.isNotEmpty
            ? t.tableLabelShort(b.tableLabel!)
            : t.typeTakeaway,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${t.itemsLabel(count)} · ${DateFormat('HH:mm').format(b.createdAt)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatRupiah(b.grandTotal),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _editBill(b),
          ),
          IconButton(
            tooltip: t.actionCancelBill,
            icon: Icon(Icons.cancel_outlined, size: 20, color: cs.error),
            onPressed: () => _cancelBill(b),
          ),
        ],
      ),
      // Tapping the row settles the bill; the pencil edits it.
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CheckoutScreen(grandTotalPreview: b.grandTotal, settleOrderId: b.id),
      )),
    );
  }

  /// Load this open bill's items into the cart for editing, then return to the order
  /// screen where the cashier adjusts it and confirms (which revises the bill in place).
  Future<void> _editBill(OrderResult b) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final catalog = ref.read(catalogProvider(session.outletId)).valueOrNull;
    if (catalog == null) return;
    ref.read(cartProvider.notifier).loadFromOrder(b, catalog);
    if (!mounted) return;
    Navigator.of(context).pop(); // back to the order screen with the bill loaded
  }

  /// Cancel an unpaid open bill: confirm + reason, manager PIN for cashiers, then
  /// release the reserved stock server-side and refresh.
  Future<void> _cancelBill(OrderResult b) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _askCancelReason();
    if (reason == null || reason.isEmpty || !mounted) return;

    final session = ref.read(sessionProvider);
    String? approverPin;
    if (session != null && !session.isOwnerOrManager) {
      approverPin = await _askApproverPin();
      if (approverPin == null || approverPin.isEmpty || !mounted) return;
    }
    try {
      await ref.read(apiClientProvider).cancelOrder(b.id, reason: reason, approverPin: approverPin);
      if (!mounted) return;
      final outletId = session!.outletId;
      ref.invalidate(openBillsProvider(outletId));
      ref.invalidate(catalogProvider(outletId)); // reserved stock released
      messenger.showSnackBar(SnackBar(content: Text(t.cancelSuccess)));
    } on DioException catch (e) {
      if (!mounted) return;
      final serverCode = e.response?.data is Map ? e.response?.data['code'] : null;
      final msg = serverCode == 'APPROVAL_INVALID'
          ? t.approvalInvalid
          : serverCode == 'APPROVAL_REQUIRED'
              ? t.approvalRequired
              : t.cancelFailed;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<String?> _askCancelReason() {
    final t = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final presets = [t.voidReasonCustomerCancel, t.voidReasonWrongItem, t.voidReasonTest];
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final cs = Theme.of(ctx).colorScheme;
          final valid = ctrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(t.cancelBillTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.cancelBillBody),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final p in presets)
                    ActionChip(
                      label: Text(p),
                      onPressed: () => setLocal(() {
                        ctrl.text = p;
                        ctrl.selection = TextSelection.collapsed(offset: p.length);
                      }),
                    ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(labelText: '${t.voidReasonLabel} *', isDense: true),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.actionCancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                onPressed: valid ? () => Navigator.of(ctx).pop(ctrl.text.trim()) : null,
                child: Text(t.actionCancelBill),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _askApproverPin() {
    final t = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.managerApprovalTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: t.managerPinLabel, isDense: true),
          onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: Text(t.actionOk)),
        ],
      ),
    );
  }
}
