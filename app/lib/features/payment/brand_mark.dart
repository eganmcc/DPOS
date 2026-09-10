import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A payment brand mark (Visa, Mastercard, BCA, GoPay, …) rendered from its bundled SVG.
///
/// The marks are placeholders until the official acceptance marks arrive from the acquirer
/// and wallet brand kits; swapping the file under `assets/images/payments/` is the whole
/// migration. If an asset is missing or fails to parse the widget falls back to a neutral
/// label, so a missing file never blanks the till.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    required this.asset,
    this.height = 20,
    this.fallbackLabel,
  });

  final String asset;
  final double height;
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SvgPicture.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => SizedBox(height: height),
      errorBuilder: (_, __, ___) => Text(
        fallbackLabel ?? '',
        style: TextStyle(
          fontSize: height * 0.6,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A row of brand marks (a card tender carries the schemes it accepts).
class BrandMarkRow extends StatelessWidget {
  const BrandMarkRow({super.key, required this.assets, this.height = 20, this.spacing = 6});

  final List<String> assets;
  final double height;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < assets.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Flexible(child: BrandMark(asset: assets[i], height: height)),
        ],
      ],
    );
  }
}
