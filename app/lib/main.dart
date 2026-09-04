import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'data/session.dart';
import 'features/auth/login_screen.dart';
import 'features/scanner/home_gate.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: DposApp()));
}

class DposApp extends ConsumerWidget {
  const DposApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Two-stage splash: the gold Android native splash hands off (no flicker) to
    // the gold Flutter splash below, which then cross-fades into login/POS.
    return MaterialApp(
      title: 'DPOS',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const _RootGate(),
    );
  }
}

/// Shows the Flutter splash on cold start, then cross-fades into the session home
/// (login or POS). The delay also masks the brief async session-restore, so a
/// logged-in user never flashes the login screen first.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _showSplash
          ? const SplashScreen()
          : (session == null ? const LoginScreen() : const HomeGate()),
    );
  }
}
