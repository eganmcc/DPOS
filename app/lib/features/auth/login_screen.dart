import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/pin_field.dart';
import '../../core/settings_actions.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';

// Seeded demo defaults (fallback when the demo directory can't be loaded).
const _demoMerchantId = 'cad63409-136c-4d01-92d2-26e493dc64ce';
const _demoOutletId = '91298a41-b8ed-4b1a-a5c9-2e4aaad036b3';

/// One demo merchant from GET /demo/directory.
class _DemoMerchant {
  final String merchantId;
  final String name;
  final String businessType;
  final String? cashierPin;
  final List<Map<String, dynamic>> outlets; // [{id, name}]
  _DemoMerchant(this.merchantId, this.name, this.businessType, this.cashierPin, this.outlets);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _merchant = TextEditingController(text: _demoMerchantId);
  final _outlet = TextEditingController(text: _demoOutletId);
  final _pin = TextEditingController(text: '1234');
  bool _loading = false;
  String? _error;

  List<_DemoMerchant> _directory = [];
  String? _selMerchantId;
  String? _selOutletId;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void dispose() {
    _merchant.dispose();
    _outlet.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    try {
      final rows = await ApiClient.demoDirectory();
      final dir = rows
          .map((m) => _DemoMerchant(
                m['merchantId'] as String,
                m['name'] as String,
                m['businessType'] as String,
                m['cashierPin'] as String?,
                (m['outlets'] as List).cast<Map<String, dynamic>>(),
              ))
          .toList();
      if (dir.isEmpty || !mounted) return;
      setState(() {
        _directory = dir;
        // Prefer the previously-defaulted F&B merchant, else the first.
        final start = dir.firstWhere((m) => m.merchantId == _demoMerchantId, orElse: () => dir.first);
        _applyMerchant(start.merchantId);
      });
    } catch (_) {
      // Offline / endpoint missing → keep the manual text-field fallback.
    }
  }

  void _applyMerchant(String merchantId) {
    final m = _directory.firstWhere((x) => x.merchantId == merchantId);
    _selMerchantId = merchantId;
    _merchant.text = merchantId;
    _selOutletId = m.outlets.isNotEmpty ? m.outlets.first['id'] as String : null;
    _outlet.text = _selOutletId ?? '';
    _pin.text = m.cashierPin ?? '';
  }

  Future<void> _login() async {
    final t = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.loginPin(_merchant.text.trim(), _pin.text.trim());
      await ref.read(sessionProvider.notifier).setSession(Session(
            token: res['token'] as String,
            merchantId: res['merchantId'] as String,
            role: res['role'] as String,
            outletId: _outlet.text.trim(),
          ));
      ref.read(sessionExpiredProvider.notifier).state = false;
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message']?.toString() ?? t.errorSignIn);
    } catch (_) {
      setState(() => _error = t.errorSignIn);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final hasDirectory = _directory.isNotEmpty;
    final selected =
        hasDirectory ? _directory.firstWhere((m) => m.merchantId == _selMerchantId) : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: LoginToggles())],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand lockup = the circle mark plus the DIKASIR wordmark.
                      // The PNG carries transparent vertical margin, so heightFactor
                      // trims that padding (the art overflows harmlessly).
                      Align(
                        alignment: Alignment.center,
                        heightFactor: 0.62,
                        child: Image.asset('assets/images/splash_circle.png', height: 210),
                      ),
                      Text(
                        'DIKASIR',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.quicksand(
                          color: cs.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              offset: const Offset(0, 3),
                              blurRadius: 7,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Shown when an authed call 401'd and signed the user out.
                      if (ref.watch(sessionExpiredProvider)) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline, size: 18, color: cs.onErrorContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(t.sessionExpired,
                                  style: TextStyle(color: cs.onErrorContainer)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Demo directory: pick a business + outlet; PIN prefills.
                      if (hasDirectory) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selMerchantId,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: t.fieldMerchantId, isDense: true),
                          items: [
                            for (final m in _directory)
                              DropdownMenuItem(
                                value: m.merchantId,
                                child: Text('${m.name} · ${m.businessType}',
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _applyMerchant(v));
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selOutletId,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: t.fieldOutletId, isDense: true),
                          items: [
                            for (final o in selected!.outlets)
                              DropdownMenuItem(
                                value: o['id'] as String,
                                child: Text(o['name'] as String, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _selOutletId = v;
                            _outlet.text = v ?? '';
                          }),
                        ),
                        const SizedBox(height: 18),
                      ],

                      Text(t.fieldPin,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      PinField(controller: _pin, length: 4, onSubmit: _login),
                      const SizedBox(height: 12),

                      // Manual override only when the directory isn't available.
                      if (!hasDirectory)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(t.advancedSettings,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            children: [
                              TextField(
                                controller: _merchant,
                                decoration:
                                    InputDecoration(labelText: t.fieldMerchantId, isDense: true),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _outlet,
                                decoration:
                                    InputDecoration(labelText: t.fieldOutletId, isDense: true),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(_error!,
                              textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(t.actionSignIn),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(t.loginFooter,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
