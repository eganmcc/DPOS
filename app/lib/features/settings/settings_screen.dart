import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/brand.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// Settings. For now it surfaces build info (app + backend versions); more
/// settings can hang off this screen later.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final appVersion = ref.watch(appVersionProvider);
    final serverVersion = ref.watch(serverVersionProvider);

    String show(AsyncValue<String> v) => v.when(
          data: (s) => s,
          loading: () => '…',
          error: (_, __) => '—',
        );

    return Scaffold(
      appBar: BrandAppBar(title: Text(t.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(t.aboutSection,
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _VersionRow(label: t.appVersionLabel, value: show(appVersion)),
                Divider(height: 1, color: cs.outline),
                _VersionRow(label: t.serverVersionLabel, value: show(serverVersion)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
