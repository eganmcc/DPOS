import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/brand.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';
import '../order/cart.dart';
import '../receipt/receipt_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.grandTotalPreview});
  final int grandTotalPreview;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _method = 'CASH';
  final _tender = TextEditingController();
  int? _selectedTender;
  bool _submitting = false;
  String? _error;

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
        _tender.text = v.toString();
        _selectedTender = v;
      });

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    final session = ref.read(sessionProvider)!;
    final cart = ref.read(cartProvider.notifier);
    if (_method == 'CASH' && (_tenderValue ?? 0) < widget.grandTotalPreview) {
      setState(() => _error = t.errorCashShort);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final payload = cart.buildPayload(
      clientOrderId: const Uuid().v4(),
      outletId: session.outletId,
      deviceId: session.deviceId,
      method: _method,
      tendered: _method == 'CASH' ? _tenderValue : null,
    );
    try {
      final result = await ref.read(syncQueueProvider).submit(payload);
      if (!mounted) return;
      cart.clear();
      if (result != null) {
        // Stock changed server-side — refetch the catalog so remaining counts
        // (and any newly sold-out items) are current when we return to the POS.
        ref.invalidate(catalogProvider(session.outletId));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ReceiptScreen(order: result)),
        );
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.msgQueuedOffline)));
      }
    } on DioException catch (e) {
      setState(() => _error = '${t.errorSignIn} (${e.response?.statusCode ?? 'network'})');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ext = brandColors(context);
    final qrPayload = 'DPOS-QRIS-SIM|amount=${widget.grandTotalPreview}';

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
                            color: kBrandGold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text(formatRupiah(widget.grandTotalPreview),
                        style: TextStyle(
                            color: ext.onGradient, fontSize: 34, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _methodCard('CASH', Icons.payments, t.methodCash)),
                  const SizedBox(width: 12),
                  Expanded(child: _methodCard('QRIS_SIMULATED', Icons.qr_code_2, t.methodQris)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: _method == 'CASH' ? _cashSection(t, cs, ext) : _qrisSection(t, qrPayload),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_method == 'CASH' ? t.actionComplete : t.actionMarkPaid),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodCard(String value, IconData icon, String label) {
    final selected = _method == value;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.secondary : cs.outline,
            width: selected ? 2 : 1,
          ),
          color: selected ? cs.secondaryContainer.withValues(alpha: 0.5) : cs.surface,
          boxShadow: selected ? kShadowE2 : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
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

  Widget _qrisSection(AppLocalizations t, String qrPayload) {
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
            child: QrImageView(data: qrPayload, size: 200),
          ),
          const SizedBox(height: 12),
          Text(t.qrisHint, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
