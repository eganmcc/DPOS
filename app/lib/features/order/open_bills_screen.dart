import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../payment/checkout_screen.dart';
import '../transactions/transaction_detail_screen.dart';
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
        MaterialPageRoute(builder: (_) => TransactionDetailScreen(orderId: o.id)),
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
      trailing: Text(formatRupiah(b.grandTotal),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CheckoutScreen(grandTotalPreview: b.grandTotal, settleOrderId: b.id),
      )),
    );
  }
}
