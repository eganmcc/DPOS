import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../payment/checkout_screen.dart';

/// Open bills (confirm-now-pay-later): pick a table to settle it.
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
    final async = ref.watch(openBillsProvider(outletId));

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.openBillsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.errorHistory)),
        data: (bills) {
          if (bills.isEmpty) {
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
          final filtered = _q.isEmpty
              ? bills
              : bills
                  .where((b) => (b.tableLabel ?? '').toUpperCase().contains(_q.toUpperCase()))
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
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
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(openBillsProvider(outletId)),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final b = filtered[i];
                      final count = b.lines
                          .fold<int>(0, (s, l) => s + (num.tryParse(l.qty)?.toInt() ?? 0));
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primary,
                          child: Text(
                            b.tableLabel?.isNotEmpty == true ? b.tableLabel! : '—',
                            style: TextStyle(
                                color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        title: Text(
                          b.tableLabel != null && b.tableLabel!.isNotEmpty
                              ? t.tableLabelShort(b.tableLabel!)
                              : t.typeTakeaway,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                            '${t.itemsLabel(count)} · ${DateFormat('HH:mm').format(b.createdAt)}'),
                        trailing: Text(formatRupiah(b.grandTotal),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            grandTotalPreview: b.grandTotal,
                            settleOrderId: b.id,
                          ),
                        )),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
