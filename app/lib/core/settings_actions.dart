import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings.dart';
import '../l10n/app_localizations.dart';

/// Two-state segmented pill (e.g. ID | EN, Terang | Gelap) for the Login top bar.
class TwoStatePill extends StatelessWidget {
  const TwoStatePill({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftActive,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftActive;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget half(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: active ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? cs.onPrimary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(leftLabel, leftActive, onLeft),
          half(rightLabel, !leftActive, onRight),
        ],
      ),
    );
  }
}

/// The pair of Login pills (language + theme).
class LoginToggles extends ConsumerWidget {
  const LoginToggles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TwoStatePill(
          leftLabel: 'ID',
          rightLabel: 'EN',
          leftActive: locale.languageCode == 'id',
          onLeft: () => ref.read(localeProvider.notifier).setLocale(const Locale('id')),
          onRight: () => ref.read(localeProvider.notifier).setLocale(const Locale('en')),
        ),
        const SizedBox(width: 8),
        TwoStatePill(
          leftLabel: t.themeLight,
          rightLabel: t.themeDark,
          leftActive: isLight,
          onLeft: () => ref.read(themeModeProvider.notifier).set(ThemeMode.light),
          onRight: () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
        ),
      ],
    );
  }
}

/// Language + theme toggles for an AppBar's `actions:`.
/// Colors adapt to the AppBar foreground (white on the navy gradient, dark on light).
class SettingsActions extends ConsumerWidget {
  const SettingsActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final brightness = Theme.of(context).brightness;
    final onBar = IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => ref.read(localeProvider.notifier).toggle(),
          style: TextButton.styleFrom(foregroundColor: onBar),
          child: Text(
            locale.languageCode.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: t.themeToggle,
          color: onBar,
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(brightness),
          icon: Icon(brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
        ),
      ],
    );
  }
}
