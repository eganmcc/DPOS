import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'data/session.dart';
import 'features/auth/login_screen.dart';
import 'features/order/order_screen.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: DposApp()));
}

class DposApp extends ConsumerStatefulWidget {
  const DposApp({super.key});

  @override
  ConsumerState<DposApp> createState() => _DposAppState();
}

class _DposAppState extends ConsumerState<DposApp> {
  /// The system splash hands over as soon as Flutter's first frame is ready,
  /// which is too quick to read as branding. Holding the app's own splash for a
  /// beat gives the diagonal time to register before the POS appears.
  static const _minimumSplash = Duration(milliseconds: 1400);
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_minimumSplash, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'DPOS',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: !_splashDone
          ? const SplashScreen()
          : (session == null ? const LoginScreen() : const OrderScreen()),
    );
  }
}
