import 'package:flutter/material.dart';

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

String? _asset(String channel) {
  switch (channel) {
    case 'GOFOOD':
      return 'assets/images/gofood.png';
    case 'GRABFOOD':
      return 'assets/images/grabfood.png';
    case 'SHOPEEFOOD':
      return 'assets/images/shopeefood.png';
    default:
      return null;
  }
}

/// Circular vendor badge. Renders the official logo PNG when it is bundled in
/// `assets/images/`, otherwise a brand-colour monogram fallback — so it looks right
/// immediately and upgrades the moment the real logos are dropped in.
Widget vendorIcon(String channel, {double size = 40}) {
  final fallback = CircleAvatar(
    radius: size / 2,
    backgroundColor: vendorColor(channel),
    child: Text(
      _monogram(channel),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.34,
      ),
    ),
  );
  final asset = _asset(channel);
  if (asset == null) return fallback;
  return ClipOval(
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    ),
  );
}
