import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../theme/brand_colors.dart';

/// Subtle brand footer: "Built by Kunal Builds · @bykunalbuilds".
class AppFooter extends StatelessWidget {
  const AppFooter({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    final text = TextSpan(
      style: TextStyle(fontSize: 13, color: muted),
      children: [
        TextSpan(text: '${PixLiftConfig.builderLine} · '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: _openInstagram,
            child: Text(
              PixLiftConfig.brandHandle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: BrandColors.cyan.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 12 : 24,
      ),
      child: Semantics(
        label:
            '${PixLiftConfig.builderLine}, Instagram ${PixLiftConfig.brandHandle}',
        child: Text.rich(text, textAlign: TextAlign.center, maxLines: 2),
      ),
    );
  }

  Future<void> _openInstagram() async {
    final uri = Uri.parse(PixLiftConfig.instagramUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
