import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Human-readable vendor name for an `OrderChannel` value.
String vendorName(String channel) {
  switch (channel) {
    case 'GOFOOD':
      return 'GoFood';
    case 'GRABFOOD':
      return 'GrabFood';
    case 'SHOPEEFOOD':
      return 'ShopeeFood';
    default:
      return channel;
  }
}

/// Each platform's brand colour (used for the fallback badge + accents).
Color vendorColor(String channel) {
  switch (channel) {
    case 'GOFOOD':
      return const Color(0xFF00AA13); // Gojek green
    case 'GRABFOOD':
      return const Color(0xFF00B14F); // Grab green
    case 'SHOPEEFOOD':
      return const Color(0xFFEE4D2D); // Shopee orange
    default:
      return const Color(0xFF607D8B);
  }
}

String _monogram(String channel) {
  switch (channel) {
    case 'GOFOOD':
      return 'GO';
    case 'GRABFOOD':
      return 'GR';
    case 'SHOPEEFOOD':
      return 'SP';
    default:
      return '?';
  }
}

/// The platform's own wordmark, bundled with the payment brand marks.
///
/// These were in the repo all along; this looked for PNGs at `assets/images/` that never
/// existed, so every order fell back to the monogram.
String? _asset(String channel) {
  switch (channel) {
    case 'GOFOOD':
      return 'assets/images/payments/gofood.svg';
    case 'GRABFOOD':
      return 'assets/images/payments/grabfood.svg';
    case 'SHOPEEFOOD':
      return 'assets/images/payments/shopeefood.svg';
    default:
      return null;
  }
}

/// The vendor's own mark, on a white chip.
///
/// A chip rather than the circular avatar this used to be, because these are **wordmarks**, not
/// square icons — GoFood is 308×63 — and a circle would crop them to a letter and a half. White
/// because the marks carry their own black and white parts: GoFood's type is `#000`, ShopeeFood's
/// cutlery is `#fff`, and either one disappears if it is handed the app's own surface in the
/// wrong theme.
///
/// Falls back to the brand-colour monogram when a mark is missing, so a bad asset never leaves a
/// hole in the list.
Widget vendorIcon(String channel, {double width = 64, double height = 40}) {
  final fallback = CircleAvatar(
    radius: height / 2,
    backgroundColor: vendorColor(channel),
    child: Text(
      _monogram(channel),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: height * 0.34,
      ),
    ),
  );
  final asset = _asset(channel);
  if (asset == null) return fallback;
  return Container(
    width: width,
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x1A000000)),
    ),
    child: SvgPicture.asset(
      asset,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, __, ___) => fallback,
    ),
  );
}
