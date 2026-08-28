import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Brand splash: the icon's diagonal, full screen, with the wordmark beneath.
///
/// Android 12+ owns the launch splash and its background can only be a single
/// colour — `windowSplashScreenBackground` takes no gradient or drawable — so
/// the diagonal has to be drawn by the app. The system splash is set to the
/// same navy, which makes the handover read as one screen rather than a flash.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Muted steel tone for the company line — reads as secondary on both halves.
  static const _subtitle = Color(0xFFA9C0DA);

  @override
  Widget build(BuildContext context) {
    final iconSize = (MediaQuery.of(context).size.width * 0.40).clamp(120.0, 200.0);
    return Scaffold(
      body: DiagonalBrandBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(iconSize * 0.22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(iconSize * 0.22),
                  child: Image.asset(
                    'assets/images/dpos_icon.png',
                    width: iconSize,
                    height: iconSize,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              SizedBox(height: iconSize * 0.30),
              const Text(
                'DPOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'PT DIKA',
                style: TextStyle(
                  color: _subtitle,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navy above-left, gold below-right, split by a **45°** line through the
/// centre — the icon's own angle.
///
/// A corner-to-corner gradient would not do: on a tall screen the corners are
/// far from 45° apart, so the split would lie much steeper than the icon's and
/// the two would visibly disagree.
class DiagonalBrandBackground extends StatelessWidget {
  const DiagonalBrandBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = brandColors(context);
    return CustomPaint(
      painter: _DiagonalPainter(
        navyTop: ext.gradientTop,
        navyBottom: ext.gradientBottom,
        gold: kBrandGold,
      ),
      child: child,
    );
  }
}

class _DiagonalPainter extends CustomPainter {
  const _DiagonalPainter({
    required this.navyTop,
    required this.navyBottom,
    required this.gold,
  });

  final Color navyTop;
  final Color navyBottom;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Navy fills everything; the gold wedge is painted over it. Keeping the
    // navy gradient matches the icon, whose navy half is not flat either.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyTop, navyBottom],
        ).createShader(rect),
    );

    // The 45° line through the centre is x + y = (w + h) / 2; gold is the side
    // where x + y is greater. Which edges it meets depends on the orientation.
    final Path wedge = Path();
    if (h >= w) {
      // Portrait: crosses the right edge high and the left edge low.
      wedge
        ..moveTo(w, (h - w) / 2)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..lineTo(0, (h + w) / 2)
        ..close();
    } else {
      // Landscape: crosses the top and bottom edges.
      wedge
        ..moveTo((w + h) / 2, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo((w - h) / 2, h)
        ..close();
    }
    canvas.drawPath(wedge, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(_DiagonalPainter old) =>
      old.navyTop != navyTop || old.navyBottom != navyBottom || old.gold != gold;
}
