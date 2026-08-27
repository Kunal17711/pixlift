import 'package:flutter/material.dart';

/// The PixLift logo, used as the visual foundation across the interface.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 1024)
        .toInt();
    return Image.asset(
      'assets/brand/pixlift-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      filterQuality: FilterQuality.high,
      semanticLabel: 'PixLift logo',
      errorBuilder: (context, error, stack) => Icon(
        Icons.auto_fix_high,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
