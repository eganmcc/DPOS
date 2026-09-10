import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../core/tts.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../order/cart.dart';
import '../receipt/receipt_screen.dart';
import '../scanner/rongta_printer.dart';
import 'brand_mark.dart';
import 'edc_screen.dart';
import 'payment_tenders.dart';

/// SUPERSEDED by [PaymentScreen] (payment_screen.dart), the tabbed redesign from the visual
/// system handoff "DPOS Checkout Redesign". Kept — not deleted — as the fallback while the new screen
/// proves itself on real shifts: nothing routes here any more (both call sites were switched on
/// 2026-09-10), so deleting this file is a one-line change once you are happy.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.grandTotalPreview, this.settleOrderId});
  final int grandTotalPreview;

  /// Non-null → settle an existing open bill (no cart, no offline queue).
  final String? settleOrderId;
  bool get isSettle => settleOrderId != null;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _method = 'CASH';
  final _tender = TextEditingController();
  int? _selectedTender;
  bool _submitting = false;
  String? _error;

  /// Set once the simulated EDC approves a card. A card sale cannot be completed without it.
  EdcResult? _edc;

  /// The wallet reference for an e-wallet tender, minted when the panel opens.
  String? _walletRef;

  Tender get _tenderSpec => tenderById(_method);

  @override
  void dispose() {
    _tender.dispose();
    super.dispose();
  }

  int? get _tenderValue => int.tryParse(_tender.text.replaceAll(RegExp(r'[^0-9]'), ''));
  int get _change => (_tenderValue ?? 0) - widget.grandTotalPreview;

  List<int> get _quickTenders {
    final g = widget.grandTotalPreview;
    int ceilTo(int step) => ((g + step - 1) ~/ step) * step;
    final set = <int>{g, ceilTo(5000), ceilTo(10000), ceilTo(50000), 50000, 100000}
        .where((v) => v >= g)
        .toList()
      ..sort();
    return set.take(4).toList();
  }

  void _setTender(int v) => setState(() {
        // Route through the formatter so the field shows grouped digits (1.500.000).
        _tender.value = ThousandsTextInputFormatter()
            .formatEditUpdate(const TextEditingValue(), TextEditingValue(text: v.toString()));
        _selectedTender = v;
      });

  /// Switching tender clears whatever the previous one had collected, so a card approval can
  /// never ride along on a different payment method.
  void _selectMethod(String id) => setState(() {
        _method = id;
        _error = null;
        _edc = null;
        _walletRef = tenderById(id).isEwallet ? const Uuid().v4() : null;
      });

  /// Card tenders go to the terminal first; the sale is only submitted once it approves.
  Future<void> _runEdc() async {
    final result = await Navigator.of(context).push<EdcResult>(
      MaterialPageRoute(
        builder: (_) => EdcScreen(amount: widget.grandTotalPreview, tenderId: _method),
      ),
    );
    if (!mounted || result == null) return; // cancelled or declined — stay on checkout
    setState(() => _edc = result);
    await _submit();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    final session = ref.read(sessionProvider)!;
    if (_method == 'CASH' && (_tenderValue ?? 0) < widget.grandTotalPreview) {
      setState(() => _error = t.errorCashShort);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final edcJson = _edc?.toJson();
      final walletJson = _tenderSpec.isEwallet ? {'reference': _walletRef} : null;

      OrderResult? result;
      if (widget.isSettle) {
        // Settling an existing open bill: post to the settle endpoint (online only).
        final json = await ref.read(apiClientProvider).settleOrder(
              widget.settleOrderId!,
              clientSettleId: const Uuid().v4(),
              method: _method,
              tendered: _method == 'CASH' ? _tenderValue : null,
              edc: edcJson,
              wallet: walletJson,
            );
        result = OrderResult.fromJson(json);
        ref.invalidate(openBillsProvider(session.outletId));
        ref.invalidate(catalogProvider(session.outletId));
      } else {
        // New immediate sale: build from the cart and go through the offline queue.
        final cart = ref.read(cartProvider.notifier);
        final payload = cart.buildPayload(
          clientOrderId: const Uuid().v4(),
          outletId: session.outletId,
          deviceId: session.deviceId,
          method: _method,
          tendered: _method == 'CASH' ? _tenderValue : null,
          edc: edcJson,
          wallet: walletJson,
        );
        result = await ref.read(syncQueueProvider).submit(payload);
        cart.clear();
        if (result != null) ref.invalidate(catalogProvider(session.outletId));
      }
      if (!mounted) return;
      if (result != null) {
        // Fire-and-forget via the app-wide TTS engine so navigating to the
        // receipt can't cut the announcement off.
        announceReceived(result.grandTotal);
        final cat = ref.read(catalogProvider(session.outletId)).valueOrNull;
        // Rongta printer → its own path (kept-open socket + cash-drawer on cash);
        // any other printer → the existing printReceipt flow. Fire-and-forget.
        // openDrawer: only a cash sale pops the drawer — a card or wallet sale never does.
        printReceiptSmart(result,
            businessName: cat?.merchantName,
            outletName: cat?.outletName,
            openDrawer: _method == 'CASH');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ReceiptScreen(order: result!)),
        );
      } else {
        // Immediate sale queued offline (no receipt yet).
        Navigator.of(context).popUntil((r) => r.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.msgQueuedOffline)));
      }
    } on DioException catch (e) {
      final code = e.response?.data is Map ? (e.response!.data as Map)['code'] : null;
      setState(() => _error = code == 'UMI_TENDER_NOT_AVAILABLE'
          ? t.tenderNotAvailable
          : '${t.errorSignIn} (${e.response?.statusCode ?? 'network'})');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);
    final session = ref.watch(sessionProvider);
    final isUmi = session != null &&
        (ref.watch(catalogProvider(session.outletId)).valueOrNull?.isUmi ?? false);
    final tenders = tendersFor(isUmi: isUmi);

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.paymentTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: brandGradient(context, radius: 20, shadow: kShadowE3),
                child: Column(
                  children: [
                    Text(t.totalDue,
                        style: TextStyle(
                            color: kBrandGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text(formatRupiah(widget.grandTotalPreview),
                        style: TextStyle(
                            color: ext.onGradient, fontSize: 34, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _tenderPicker(t, tenders, isUmi),
                      const SizedBox(height: 20),
                      switch (_tenderSpec.kind) {
                        TenderKind.cash => _cashSection(t, cs, ext),
                        TenderKind.qris => _qrSection(
                            t, 'DPOS-QRIS-SIM|amount=${widget.grandTotalPreview}', t.qrisHint),
                        TenderKind.card => _cardSection(t, cs),
                        TenderKind.ewallet => _walletSection(t, cs),
                        TenderKind.online => const SizedBox.shrink(),
                      },
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              const SizedBox(height: 8),
              _primaryAction(t),
            ],
          ),
        ),
      ),
    );
  }

  /// Cash and QRIS stay on one row; card and wallet tenders get their own labelled groups so a
  /// busy till reads as three short lists rather than one wall of eight buttons.
  Widget _tenderPicker(AppLocalizations t, List<Tender> tenders, bool isUmi) {
    final basics = tenders.where((x) => x.kind == TenderKind.cash || x.kind == TenderKind.qris);
    final cards = tenders.where((x) => x.isCard).toList();
    final wallets = tenders.where((x) => x.isEwallet).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final x in basics) ...[
              if (x != basics.first) const SizedBox(width: 12),
              Expanded(child: _tenderCard(t, x)),
            ],
          ],
        ),
        if (cards.isNotEmpty) ...[
          const SizedBox(height: 16),
          _groupLabel(t.tenderGroupCard),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final x in cards) ...[
                if (x != cards.first) const SizedBox(width: 12),
                Expanded(child: _tenderCard(t, x)),
              ],
            ],
          ),
        ],
        if (wallets.isNotEmpty) ...[
          const SizedBox(height: 16),
          _groupLabel(t.tenderGroupEwallet),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final x in wallets) ...[
                if (x != wallets.first) const SizedBox(width: 12),
                Expanded(child: _tenderCard(t, x)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _groupLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(text.toUpperCase(),
        style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1));
  }

  Widget _tenderCard(AppLocalizations t, Tender tender) {
    final selected = _method == tender.id;
    final cs = Theme.of(context).colorScheme;
    final accent = tender.brandColor ?? cs.secondary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _selectMethod(tender.id),
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : cs.outline,
            width: selected ? 2 : 1,
          ),
          color: selected ? accent.withValues(alpha: 0.08) : cs.surface,
          boxShadow: selected ? kShadowE2 : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (tender.assets.isNotEmpty)
              BrandMarkRow(assets: tender.assets, height: 18)
            else
              Icon(tender.icon, size: 26, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              tender.label(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom action. A card sale routes through the terminal first and only then completes.
  Widget _primaryAction(AppLocalizations t) {
    final needsEdc = _tenderSpec.isCard && _edc == null;
    final label = needsEdc
        ? t.actionProcessCard
        : (_tenderSpec.isEwallet ? t.actionWalletConfirm : t.actionComplete);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: _submitting
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(needsEdc ? Icons.credit_card : Icons.check, size: 18),
        label: Text(_submitting ? '' : label),
        onPressed: _submitting ? null : (needsEdc ? _runEdc : _submit),
      ),
    );
  }

  Widget _cashSection(AppLocalizations t, ColorScheme cs, DposColors ext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final v in _quickTenders)
              ChoiceChip(
                label: Text(v == widget.grandTotalPreview ? t.tenderExact : formatRupiah(v)),
                selected: _selectedTender == v,
                showCheckmark: false,
                selectedColor: cs.primary,
                labelStyle: TextStyle(
                    color: _selectedTender == v ? cs.onPrimary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600),
                onSelected: (_) => _setTender(v),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _tender,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.end,
          inputFormatters: [ThousandsTextInputFormatter()],
          decoration: InputDecoration(labelText: t.fieldCashReceived, prefixText: 'Rp '),
          onChanged: (_) => setState(() => _selectedTender = null),
        ),
        const SizedBox(height: 16),
        if (_tenderValue != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ext.successContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.labelChange,
                    style: TextStyle(color: ext.onSuccessContainer, fontWeight: FontWeight.w600)),
                Text(formatRupiah(_change < 0 ? 0 : _change),
                    style: TextStyle(
                        color: ext.onSuccessContainer, fontWeight: FontWeight.w800, fontSize: 19)),
              ],
            ),
          ),
      ],
    );
  }

  /// One QR renderer for QRIS and every wallet — they are all QRIS issuers in practice.
  Widget _qrSection(AppLocalizations t, String payload, String hint, {List<String> marks = const []}) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBrandGold, width: 2),
            ),
            child: QrImageView(data: payload, size: 180),
          ),
          if (marks.isNotEmpty) ...[
            const SizedBox(height: 12),
            BrandMarkRow(assets: marks, height: 24),
          ],
          const SizedBox(height: 12),
          Text(hint, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _walletSection(AppLocalizations t, ColorScheme cs) {
    final wallet = _tenderSpec;
    return _qrSection(
      t,
      'DPOS-${wallet.id}-SIM|amount=${widget.grandTotalPreview}|ref=$_walletRef',
      t.walletScanHint(wallet.label(t)),
      marks: wallet.assets,
    );
  }

  /// Card panel: before the terminal runs it explains what happens; after approval it shows the
  /// approval code, so the cashier can match the slip before completing.
  Widget _cardSection(AppLocalizations t, ColorScheme cs) {
    final approved = _edc;
    if (approved == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            BrandMarkRow(assets: _tenderSpec.assets, height: 28),
            const SizedBox(height: 14),
            Icon(Icons.credit_card, size: 32, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(t.edcInsertCard,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, letterSpacing: 1.1)),
          ],
        ),
      );
    }

    final ext = brandColors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ext.successContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: ext.onSuccessContainer, size: 20),
              const SizedBox(width: 8),
              Text(t.cardApprovedShort(approved.approvalCode),
                  style: TextStyle(
                      color: ext.onSuccessContainer, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${approved.scheme} · ${approved.maskedPan} · ${approved.entryMode}',
              style: TextStyle(
                  color: ext.onSuccessContainer, fontSize: 12, fontFamily: 'monospace')),
          Text('RRN ${approved.rrn}',
              style: TextStyle(
                  color: ext.onSuccessContainer, fontSize: 12, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
