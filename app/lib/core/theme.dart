import 'package:flutter/material.dart';

/// PT DIKA brand palette (Direction A — "DIKA Bold").
const Color kBrandNavy = Color(0xFF133A68);
const Color kBrandGold = Color(0xFFD6AD07);

/// Extra brand roles not covered by Material's ColorScheme (success + header gradient).
@immutable
class DposColors extends ThemeExtension<DposColors> {
  const DposColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.gradientTop,
    required this.gradientBottom,
    required this.onGradient,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color gradientTop;
  final Color gradientBottom;
  final Color onGradient;

  LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientTop, gradientBottom],
      );

  @override
  DposColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? gradientTop,
    Color? gradientBottom,
    Color? onGradient,
  }) =>
      DposColors(
        success: success ?? this.success,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        gradientTop: gradientTop ?? this.gradientTop,
        gradientBottom: gradientBottom ?? this.gradientBottom,
        onGradient: onGradient ?? this.onGradient,
      );

  @override
  DposColors lerp(DposColors? other, double t) {
    if (other == null) return this;
    return DposColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      gradientTop: Color.lerp(gradientTop, other.gradientTop, t)!,
      gradientBottom: Color.lerp(gradientBottom, other.gradientBottom, t)!,
      onGradient: Color.lerp(onGradient, other.onGradient, t)!,
    );
  }
}

const _lightExt = DposColors(
  success: Color(0xFF1E7B45),
  successContainer: Color(0xFFDCF3E3),
  onSuccessContainer: Color(0xFF0B3D21),
  gradientTop: Color(0xFF0B2036),
  gradientBottom: Color(0xFF133A68),
  onGradient: Colors.white,
);

const _darkExt = DposColors(
  success: Color(0xFF6FCF97),
  successContainer: Color(0xFF163521),
  onSuccessContainer: Color(0xFFB6EFC9),
  gradientTop: Color(0xFF060A12),
  gradientBottom: Color(0xFF122239),
  onGradient: Colors.white,
);

// Layered, navy-tinted shadows (e2/e3) — flat grey Material shadows read as "pale".
const List<BoxShadow> kShadowE2 = [
  BoxShadow(color: Color(0x1F133A68), blurRadius: 8, offset: Offset(0, 2)),
];
const List<BoxShadow> kShadowE3 = [
  BoxShadow(color: Color(0x2E133A68), blurRadius: 24, offset: Offset(0, 8)),
];

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: kBrandNavy,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFDCE6F2),
  onPrimaryContainer: Color(0xFF0B2036),
  secondary: kBrandGold,
  onSecondary: Color(0xFF2B1D00),
  secondaryContainer: Color(0xFFFBEDBB),
  onSecondaryContainer: Color(0xFF453200),
  tertiary: kBrandGold,
  onTertiary: Color(0xFF2B1D00),
  error: Color(0xFFB3261E),
  onError: Colors.white,
  surface: Colors.white,
  onSurface: Color(0xFF16181D),
  surfaceContainerHighest: Color(0xFFEAE7DD),
  surfaceContainerHigh: Color(0xFFEAE7DD),
  surfaceContainer: Color(0xFFF2F0E9),
  onSurfaceVariant: Color(0xFF5B6472),
  outline: Color(0xFFD8D4C8),
  outlineVariant: Color(0xFFE4E1D7),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF9DBEE8),
  onPrimary: Color(0xFF0B2036),
  primaryContainer: Color(0xFF1F3A5C),
  onPrimaryContainer: Color(0xFFD3E3F5),
  secondary: Color(0xFFE8C34A),
  onSecondary: Color(0xFF3D2E00),
  secondaryContainer: Color(0xFF5A4300),
  onSecondaryContainer: Color(0xFFFBEDBB),
  tertiary: Color(0xFFE8C34A),
  onTertiary: Color(0xFF3D2E00),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  surface: Color(0xFF101A2C),
  onSurface: Color(0xFFE7EAF1),
  surfaceContainerHighest: Color(0xFF1F2C48),
  surfaceContainerHigh: Color(0xFF1F2C48),
  surfaceContainer: Color(0xFF17223A),
  onSurfaceVariant: Color(0xFFA6AFC2),
  outline: Color(0xFF2C3A56),
  outlineVariant: Color(0xFF24314C),
);

ThemeData buildLightTheme() => _base(_lightScheme, _lightExt, const Color(0xFFF7F5EF));
ThemeData buildDarkTheme() => _base(_darkScheme, _darkExt, const Color(0xFF0B111C));

ThemeData _base(ColorScheme scheme, DposColors ext, Color canvas) {
  final stadium = RoundedRectangleBorder(borderRadius: BorderRadius.circular(100));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    extensions: [ext],
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ext.onGradient,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: ext.onGradient, fontSize: 18, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: kBrandNavy,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.secondary, // gold CTA
        foregroundColor: scheme.onSecondary,
        shape: stadium,
        elevation: 2,
        shadowColor: kBrandGold.withValues(alpha: 0.4),
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: 1.5),
        shape: stadium,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainer,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outline),
      backgroundColor: scheme.surface,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
  );
}

/// True on a tablet-sized screen — drives the two-pane layout.
bool isWide(BuildContext context) => MediaQuery.of(context).size.width >= 720;

DposColors brandColors(BuildContext context) => Theme.of(context).extension<DposColors>()!;
