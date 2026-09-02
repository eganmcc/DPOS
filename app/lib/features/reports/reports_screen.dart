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
import '../scanner/home_gate.dart'; // PosHome
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';

enum _Period { daily, weekly, monthly }

DateRange _rangeFor(_Period p) {
  final now = DateTime.now();
  String f(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  switch (p) {
    case _Period.daily:
      return (from: f(now), to: f(now));
    case _Period.weekly:
      return (from: f(now.subtract(const Duration(days: 6))), to: f(now));
    case _Period.monthly:
      return (from: f(DateTime(now.year, now.month, 1)), to: f(now));
  }
}

/// Owner/manager home: sales summary (daily/weekly/monthly) + employee attendance,
/// backed by GET /admin/dashboard and GET /admin/attendance. The cashier POS stays
/// reachable via "Open cashier".
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Period _period = _Period.daily;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final range = _rangeFor(_period);
    final dash = ref.watch(dashboardProvider(range));
    final attendance = ref.watch(adminAttendanceProvider(range));

    return Scaffold(
      appBar: BrandAppBar(
        title: Text(t.reportsTitle),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosHome())),
            style: TextButton.styleFrom(foregroundColor: kBrandGold),
            child: Text(t.reportsOpenCashier, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: t.historyLabel,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TransactionsScreen())),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: t.settingsTitle,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: t.actionLogout,
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider(range));
          ref.invalidate(adminAttendanceProvider(range));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // Period toggle.
            SegmentedButton<_Period>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _Period.daily, label: Text(t.periodDaily)),
                ButtonSegment(value: _Period.weekly, label: Text(t.periodWeekly)),
                ButtonSegment(value: _Period.monthly, label: Text(t.periodMonthly)),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 14),

            // Sales.
            dash.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _InlineError(
                message: t.errorHistory,
                onRetry: () => ref.invalidate(dashboardProvider(range)),
              ),
              data: (d) => Column(
                children: [
                  _HeaderCard(d: d),
                  const SizedBox(height: 14),
                  if (d.paymentBreakdown.isNotEmpty) ...[
                    _SectionCard(
                      title: t.reportsPayments,
                      child: Column(children: [
                        for (final p in d.paymentBreakdown)
                          _Row(label: _methodLabel(p.method), value: formatRupiah(p.amount)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (d.topItems.isNotEmpty) ...[
                    _SectionCard(
                      title: t.reportsTopItems,
                      child: Column(children: [
                        for (final it in d.topItems)
                          _Row(
                              label: it.name,
                              sub: t.reportsQtySold(it.qty),
                              value: formatRupiah(it.sales)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (d.byOutlet.length > 1) ...[
                    _SectionCard(
                      title: t.reportsByOutlet,
                      child: Column(children: [
                        for (final o in d.byOutlet)
                          _Row(
                              label: o.name,
                              sub: t.historyCount(o.count),
                              value: formatRupiah(o.sales)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (d.salesByDay.isNotEmpty) ...[
                    _SectionCard(title: t.reportsByDay, child: _DayBars(days: d.salesByDay)),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),

            // Attendance.
            attendance.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => _InlineError(
                message: t.errorHistory,
                onRetry: () => ref.invalidate(adminAttendanceProvider(range)),
              ),
              data: (rows) => _SectionCard(
                title: t.reportsAttendance,
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(t.reportsNoAttendance,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13)),
                      )
                    : Column(children: [for (final r in rows) _AttendanceTile(row: r)]),
              ),
            ),
          ],
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
          Row(children: [
            _Stat(label: t.reportsOrders, value: '${d.orderCount}', color: ext.onGradient),
            const SizedBox(width: 24),
            _Stat(label: t.reportsAvgTicket, value: formatRupiah(d.avgTicket), color: ext.onGradient),
          ]),
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
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (sub != null)
              Text(sub!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ]),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.row});
  final AttendanceRow row;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final inT = DateFormat('dd/MM HH:mm').format(row.clockInAt);
    final outT = row.clockOutAt == null ? '—' : DateFormat('HH:mm').format(row.clockOutAt!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.staffName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$inT → $outT',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ]),
        ),
        row.open
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(t.attendanceOnClock,
                    style: TextStyle(
                        color: cs.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.w700)),
              )
            : Text(_hm(row.minutes ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}j ${m}m' : '${m}m';
  }
}

class _DayBars extends StatelessWidget {
  const _DayBars({required this.days});
  final List<({String day, int sales})> days;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = days.fold<int>(1, (m, d) => d.sales > m ? d.sales : m);
    return Column(children: [
      for (final d in days)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
                width: 46,
                child: Text(_shortDay(d.day),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        ),
    ]);
  }

  String _shortDay(String iso) {
    try {
      return DateFormat('dd/MM').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: Text(t.actionRetry)),
      ]),
    );
  }
}
