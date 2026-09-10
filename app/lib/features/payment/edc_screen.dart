import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../l10n/app_localizations.dart';
import 'brand_mark.dart';
import 'payment_tenders.dart';

/// What the EDC hands back once it has authorized the card. Mirrors `EdcDto` on the server.
class EdcResult {
  const EdcResult({
    required this.scheme,
    required this.maskedPan,
    required this.entryMode,
    required this.approvalCode,
    required this.rrn,
    required this.traceNo,
    required this.batchNo,
    required this.terminalId,
  });

  final String scheme;
  final String maskedPan;
  final String entryMode;
  final String approvalCode;
  final String rrn;
  final String traceNo;
  final String batchNo;
  final String terminalId;

  Map<String, dynamic> toJson() => {
        'scheme': scheme,
        'maskedPan': maskedPan,
        'entryMode': entryMode,
        'approvalCode': approvalCode,
        'rrn': rrn,
        'traceNo': traceNo,
        'batchNo': batchNo,
        'terminalId': terminalId,
      };
}

enum _Stage { waiting, reading, authorizing, approved, declined }

/// Simulated EDC terminal round-trip for the card tenders.
///
/// Stands in for a real terminal until an EDC integration exists: the cashier presents the
/// card, the terminal authorizes, and the approval data comes back to the till exactly as a
/// device would return it — approval code, RRN, masked PAN, trace and batch. The server
/// validates that evidence and owns the resulting payment status; nothing here decides money.
///
/// Returns an [EdcResult] on approval, or null if the cashier cancelled or the card declined.
class EdcScreen extends StatefulWidget {
  const EdcScreen({super.key, required this.amount, required this.tenderId});

  final int amount;
  final String tenderId; // CARD_CREDIT | CARD_DEBIT | CARD_BCA

  @override
  State<EdcScreen> createState() => _EdcScreenState();
}

class _EdcScreenState extends State<EdcScreen> {
  static const _terminalId = 'DPOS0001';
  final _rng = Random();

  _Stage _stage = _Stage.waiting;
  String _entryMode = 'CHIP';
  late String _scheme = widget.tenderId == 'CARD_BCA' ? 'BCA' : 'VISA';
  EdcResult? _result;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _digits(int n) => List.generate(n, (_) => _rng.nextInt(10)).join();

  String _maskedPan() {
    // BCA debit runs on a 4-series BIN, so only Mastercard starts with 5.
    final first = _scheme == 'MASTERCARD' ? '5' : '4';
    return '$first*** **** **** ${_digits(4)}';
  }

  /// Runs the terminal states with realistic pauses, then approves (or declines).
  void _process({bool decline = false}) {
    setState(() => _stage = _Stage.reading);
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _stage = _Stage.authorizing);
      _timer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        if (decline) {
          setState(() => _stage = _Stage.declined);
          return;
        }
        setState(() {
          _result = EdcResult(
            scheme: _scheme,
            maskedPan: _maskedPan(),
            entryMode: _entryMode,
            approvalCode: _digits(6),
            rrn: _digits(12),
            traceNo: _digits(6),
            batchNo: _digits(6),
            terminalId: _terminalId,
          );
          _stage = _Stage.approved;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final tender = tenderById(widget.tenderId);

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.edcTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _terminalPanel(t, tender),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_stage) {
                    _Stage.waiting => _cardPresentation(t),
                    _Stage.approved => _slip(t, _result!),
                    _Stage.declined => _declined(t),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
              _actions(t),
            ],
          ),
        ),
      ),
    );
  }

  /// The terminal display: amount and current state.
  Widget _terminalPanel(AppLocalizations t, Tender tender) {
    final busy = _stage == _Stage.reading || _stage == _Stage.authorizing;
    final message = switch (_stage) {
      _Stage.waiting => t.edcInsertCard,
      _Stage.reading => t.edcReadingCard,
      _Stage.authorizing => t.edcAuthorizing,
      _Stage.approved => t.edcApproved,
      _Stage.declined => t.edcDeclined,
    };
    final tone = switch (_stage) {
      _Stage.approved => const Color(0xFF34D399),
      _Stage.declined => const Color(0xFFF87171),
      _ => Colors.white,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        // Terminal slate, deliberately not the brand navy: this is a device, not the app.
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('EDC · $_terminalId',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace')),
              if (tender.assets.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration:
                      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                  child: BrandMarkRow(assets: tender.assets, height: 14),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(formatRupiah(widget.amount),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                ),
              Flexible(
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: tone, fontSize: 13, letterSpacing: 1.1, fontFamily: 'monospace')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Before processing: how the card is presented, mirroring what the cashier physically does.
  Widget _cardPresentation(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    final schemes = widget.tenderId == 'CARD_BCA' ? ['BCA'] : ['VISA', 'MASTERCARD'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.edcEntryMode, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final m in const ['CHIP', 'CONTACTLESS', 'SWIPE'])
              ChoiceChip(
                label: Text(switch (m) {
                  'CHIP' => t.edcChip,
                  'CONTACTLESS' => t.edcContactless,
                  _ => t.edcSwipe,
                }),
                selected: _entryMode == m,
                showCheckmark: false,
                onSelected: (_) => setState(() => _entryMode = m),
              ),
          ],
        ),
        if (schemes.length > 1) ...[
          const SizedBox(height: 16),
          Text(t.edcScheme, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in schemes)
                ChoiceChip(
                  label: Text(s == 'VISA' ? 'Visa' : 'Mastercard'),
                  selected: _scheme == s,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _scheme = s),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// After approval: the slip the terminal prints, which is also what the payment stores.
  Widget _slip(AppLocalizations t, EdcResult r) {
    final cs = Theme.of(context).colorScheme;
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              Text(v,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          line(t.edcCard, '${r.scheme} · ${r.maskedPan}'),
          line(t.edcEntryMode, r.entryMode),
          line(t.edcApprovalCode, r.approvalCode),
          line(t.edcRrn, r.rrn),
          line(t.edcTrace, '${r.traceNo} / ${r.batchNo}'),
          line(t.edcTerminal, r.terminalId),
        ],
      ),
    );
  }

  Widget _declined(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.credit_card_off, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(t.edcDeclinedHint, style: TextStyle(color: cs.onErrorContainer))),
        ],
      ),
    );
  }

  Widget _actions(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    switch (_stage) {
      case _Stage.waiting:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.credit_card, size: 18),
                label: Text(t.edcProcess),
                onPressed: () => _process(),
              ),
            ),
            TextButton(
              // Deliberately plain: a decline is a training/demo path, not a till action.
              onPressed: () => _process(decline: true),
              child: Text(t.edcSimulateDecline,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ),
          ],
        );
      case _Stage.reading:
      case _Stage.authorizing:
        return const SizedBox(height: 48);
      case _Stage.approved:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: Text(t.edcContinue),
          ),
        );
      case _Stage.declined:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.actionCancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _stage = _Stage.waiting),
                child: Text(t.edcRetry),
              ),
            ),
          ],
        );
    }
  }
}
