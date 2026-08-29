import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../scanner/receipt_printer.dart';
import '../transactions/transaction_status.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.order});
  final OrderResult order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ts = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
    final payment = order.payments.isNotEmpty ? order.payments.first : null;
    // Company + outlet names from the current outlet's catalog (never hardcoded).
    final session = ref.watch(sessionProvider);
    final catalog =
        session != null ? ref.watch(catalogProvider(session.outletId)).valueOrNull : null;
    final businessName = catalog?.merchantName ?? t.appTitle;

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.receiptTitle)),
      body: Container(
        color: cs.surfaceContainerHigh,
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: Image.asset('assets/images/dika_logo.png', height: 44)),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(businessName,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (catalog?.outletName != null)
                          Center(
                            child: Text(catalog!.outletName!,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('#${order.id.substring(0, 8)}',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                            StatusChip(status: order.effectiveStatus),
                          ],
                        ),
                        Text(ts, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                        _DashedDivider(color: cs.outline),
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
                        _DashedDivider(color: cs.outline),
                        _row(context, t.labelSubtotal, order.subtotal),
                        if (order.discountTotal > 0) _row(context, t.labelDiscount, -order.discountTotal),
                        _row(context, order.taxLabelSnapshot ?? t.labelTax, order.taxTotal),
                        if (order.serviceChargeTotal > 0)
                          _row(context, t.labelService, order.serviceChargeTotal),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(t.labelTotal,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
                            Text(formatRupiah(order.grandTotal),
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.primary)),
                          ],
                        ),
                        if (payment != null) ...[
                          const SizedBox(height: 6),
                          _row(context, payment.method, payment.amount, muted: true),
                          if (payment.change != null) _row(context, t.labelChange, payment.change!, muted: true),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: Text(t.actionPrint),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await printReceipt(order,
                                  businessName: businessName, outletName: catalog?.outletName);
                              if (!ok) {
                                messenger.showSnackBar(SnackBar(content: Text(t.printFailed)));
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.share_outlined, size: 18),
                                label: Text(t.actionShare),
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(t.shareSoon))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                                child: Text(t.actionNewOrder),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int amount, {bool muted = false}) {
    final cs = Theme.of(context).colorScheme;
    final style = muted ? TextStyle(color: cs.onSurfaceVariant, fontSize: 13) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(formatRupiah(amount), style: style)],
      ),
    );
  }
}

/// Receipt-paper dashed divider.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: LayoutBuilder(
        builder: (context, box) {
          const dash = 5.0, gap = 4.0;
          final count = (box.maxWidth / (dash + gap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (_) => SizedBox(width: dash, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: color))),
            ),
          );
        },
      ),
    );
  }
}
