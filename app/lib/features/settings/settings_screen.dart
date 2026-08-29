import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/brand.dart';
import '../../core/settings.dart';
import '../../core/settings_actions.dart';
import '../../data/providers.dart';
import '../../data/session.dart';
import '../../l10n/app_localizations.dart';

/// Settings: preferences (language, theme), build info (app + backend versions),
/// and logout — all moved out of the order-screen app bar.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final appVersion = ref.watch(appVersionProvider);
    final serverVersion = ref.watch(serverVersionProvider);
    final session = ref.watch(sessionProvider);
    final isGrocery = session != null &&
        (ref.watch(catalogProvider(session.outletId)).valueOrNull?.isGrocery ?? false);
    final scannerMode = ref.watch(scannerModeSettingProvider);

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
          _sectionHeader(context, t.preferencesSection),
          _card(cs, [
            _SettingsRow(
              label: t.languageLabel,
              trailing: TwoStatePill(
                leftLabel: 'ID',
                rightLabel: 'EN',
                leftActive: locale.languageCode == 'id',
                onLeft: () => ref.read(localeProvider.notifier).setLocale(const Locale('id')),
                onRight: () => ref.read(localeProvider.notifier).setLocale(const Locale('en')),
              ),
            ),
            _divider(cs),
            _SettingsRow(
              label: t.themeLabel,
              trailing: TwoStatePill(
                leftLabel: t.themeLight,
                rightLabel: t.themeDark,
                leftActive: isLight,
                onLeft: () => ref.read(themeModeProvider.notifier).set(ThemeMode.light),
                onRight: () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
              ),
            ),
          ]),
          if (isGrocery) ...[
            const SizedBox(height: 24),
            _sectionHeader(context, t.scannerModeLabel),
            _card(cs, [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'auto', label: Text(t.scannerModeAuto)),
                    ButtonSegment(value: 'on', label: Text(t.scannerModeOn)),
                    ButtonSegment(value: 'off', label: Text(t.scannerModeOff)),
                  ],
                  selected: {scannerMode},
                  onSelectionChanged: (s) =>
                      ref.read(scannerModeSettingProvider.notifier).set(s.first),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 24),
          _sectionHeader(context, t.aboutSection),
          _card(cs, [
            _SettingsRow(label: t.appVersionLabel, trailing: _value(show(appVersion))),
            _divider(cs),
            _SettingsRow(label: t.serverVersionLabel, trailing: _value(show(serverVersion))),
          ]),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(sessionProvider.notifier).logout();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout),
            label: Text(t.actionLogout),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );

  Widget _card(ColorScheme cs, List<Widget> children) => Container(
        decoration:
            BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(16)),
        child: Column(children: children),
      );

  Widget _divider(ColorScheme cs) => Divider(height: 1, color: cs.outline);

  Widget _value(String v) => Text(v, style: const TextStyle(fontWeight: FontWeight.w700));
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          trailing,
        ],
      ),
    );
  }
}
