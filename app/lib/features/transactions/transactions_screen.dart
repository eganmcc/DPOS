import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import 'transaction_detail_screen.dart';
import 'transaction_status.dart';

/// US3 (T038) — transaction history for the current outlet, newest first.
/// Read straight from the API: the server is the system of record for effective status.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider)!;
    final async = ref.watch(transactionsProvider(session.outletId));

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.historyTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: t.errorHistory,
          onRetry: () => ref.invalidate(transactionsProvider(session.outletId)),
        ),
        data: (orders) {
          if (orders.isEmpty) return _EmptyState(message: t.emptyHistory);
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(transactionsProvider(session.outletId).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: orders.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == 0) return _DayTotals(orders: orders);
                return _TransactionTile(order: orders[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Header strip: what the outlet actually took, with voided sales excluded from the total.
class _DayTotals extends StatelessWidget {
  const _DayTotals({required this.orders});
  final List<OrderResult> orders;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ext = brandColors(context);
    final counted = orders.where((o) => !o.isVoided && !o.isRefunded).toList();
    final net = counted.fold<int>(0, (s, o) => s + o.grandTotal);
    final voided = orders.where((o) => o.isVoided).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: brandGradient(context, radius: 16, shadow: kShadowE2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.historyNetSales,
                    style: TextStyle(
                        color: kBrandGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Text(formatRupiah(net),
                    style: TextStyle(
                        color: ext.onGradient, fontSize: 24, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(t.historyCount(counted.length),
                  style: TextStyle(color: ext.onGradient.withValues(alpha: 0.85), fontSize: 13)),
              if (voided > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(t.historyVoidedCount(voided),
                      style:
                          TextStyle(color: ext.onGradient.withValues(alpha: 0.7), fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.order});
  final OrderResult order;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = DateFormat('dd/MM/yyyy · HH:mm').format(order.createdAt);
    final items = order.lines.length;
    final charges = order.payments.where((p) => !p.isReversal).toList();
    final method = charges.isEmpty ? '' : charges.first.method;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TransactionDetailScreen(orderId: order.id)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text('#${shortOrderId(order.id)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(formatRupiah(order.grandTotal),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: order.isVoided ? cs.onSurfaceVariant : cs.primary,
                  decoration: order.isVoided ? TextDecoration.lineThrough : null,
                )),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$time · ${AppLocalizations.of(context)!.itemsLabel(items)}'
                  '${method.isEmpty ? '' : ' · $method'}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: order.effectiveStatus, dense: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 44, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.actionRetry),
          ),
        ],
      ),
    );
  }
}
