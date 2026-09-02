import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// Owner/manager sales summary, backed by GET /admin/dashboard (merchant-wide,
/// all outlets, last 7 days by default). Read-only.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.reportsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: t.errorHistory,
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _HeaderCard(d: d),
              const SizedBox(height: 14),
              if (d.paymentBreakdown.isNotEmpty) ...[
                _SectionCard(
                  title: t.reportsPayments,
                  child: Column(
                    children: [
                      for (final p in d.paymentBreakdown)
                        _Row(label: _methodLabel(p.method), value: formatRupiah(p.amount)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (d.topItems.isNotEmpty) ...[
                _SectionCard(
                  title: t.reportsTopItems,
                  child: Column(
                    children: [
                      for (final it in d.topItems)
                        _Row(
                          label: it.name,
                          sub: t.reportsQtySold(it.qty),
                          value: formatRupiah(it.sales),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (d.byOutlet.length > 1) ...[
                _SectionCard(
                  title: t.reportsByOutlet,
                  child: Column(
                    children: [
                      for (final o in d.byOutlet)
                        _Row(
                          label: o.name,
                          sub: t.historyCount(o.count),
                          value: formatRupiah(o.sales),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (d.salesByDay.isNotEmpty)
                _SectionCard(
                  title: t.reportsByDay,
                  child: _DayBars(days: d.salesByDay),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'CASH':
        return 'Cash';
      case 'QRIS_SIMULATED':
        return 'QRIS';
      case 'ONLINE':
        return 'Online';
      default:
        return m;
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.d});
  final DashboardSummary d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final ext = brandColors(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: brandGradient(context, radius: 16, shadow: kShadowE2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.historyNetSales,
              style: const TextStyle(
                  color: kBrandGold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(formatRupiah(d.netSales),
              style: TextStyle(color: ext.onGradient, fontSize: 28, fontWeight: FontWeight.w800)),
          if (d.from != null && d.to != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${d.from} → ${d.to}',
                  style: TextStyle(color: ext.onGradient.withValues(alpha: 0.75), fontSize: 12)),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: t.reportsOrders, value: '${d.orderCount}', color: ext.onGradient),
              const SizedBox(width: 24),
              _Stat(label: t.reportsAvgTicket, value: formatRupiah(d.avgTicket), color: ext.onGradient),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.sub});
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (sub != null)
                  Text(sub!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DayBars extends StatelessWidget {
  const _DayBars({required this.days});
  final List<({String day, int sales})> days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = days.fold<int>(1, (m, d) => d.sales > m ? d.sales : m);
    return Column(
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(_shortDay(d.day),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: d.sales / max,
                      minHeight: 14,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation(kBrandGold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 84,
                  child: Text(formatRupiah(d.sales),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _shortDay(String iso) {
    try {
      return DateFormat('dd/MM').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(t.actionRetry)),
        ],
      ),
    );
  }
}
