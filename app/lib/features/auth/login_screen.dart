import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/pin_field.dart';
import '../../core/settings_actions.dart';
import '../../data/api_client.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';

// Seeded demo defaults (from `npm run seed`). Prefilled for a quick board demo.
const _demoMerchantId = 'cad63409-136c-4d01-92d2-26e493dc64ce';
const _demoOutletId = '91298a41-b8ed-4b1a-a5c9-2e4aaad036b3';

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

  @override
  void dispose() {
    _merchant.dispose();
    _outlet.dispose();
    _pin.dispose();
    super.dispose();
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
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/images/dika_logo.png', height: 64),
                      const SizedBox(height: 16),
                      Text('DPOS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
                      Text('PT DIKA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      Text(t.loginTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      Text(t.fieldPin,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      PinField(controller: _pin, length: 4, onSubmit: _login),
                      const SizedBox(height: 12),
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
                              decoration: InputDecoration(labelText: t.fieldMerchantId, isDense: true),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _outlet,
                              decoration: InputDecoration(labelText: t.fieldOutletId, isDense: true),
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
