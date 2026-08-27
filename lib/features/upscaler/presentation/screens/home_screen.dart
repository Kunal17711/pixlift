import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants.dart';
import '../../../../theme/brand_colors.dart';
import '../../../../widgets/app_footer.dart';
import '../../../../widgets/brand_logo.dart';
import '../../../../widgets/primary_button.dart';
import '../upscale_controller.dart';

/// The landing screen: logo, hookline, one clear CTA.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpscaleController>();
    final error = controller.errorMessage;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BrandColors.deepGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      const Center(child: BrandLogo(size: 128)),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'PixLift',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: BrandColors.textOnDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        PixLiftConfig.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        PixLiftConfig.supportLine,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: BrandColors.textMutedDark,
                        ),
                      ),
                      const Spacer(flex: 2),
                      PrimaryButton(
                        label: 'Pick a photo',
                        icon: Icons.photo_library_outlined,
                        onPressed: controller.pickPhoto,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No uploads. No watermark. Just pixels getting better.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: BrandColors.textMutedDark,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TrustChip(
                            icon: Icons.smartphone_rounded,
                            label: 'On-device',
                          ),
                          _TrustChip(
                            icon: Icons.water_drop_outlined,
                            label: 'No watermark',
                          ),
                          _TrustChip(
                            icon: Icons.verified_outlined,
                            label: 'Free',
                          ),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFB4AB),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const AppFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: BrandColors.cyan),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: BrandColors.textOnDark),
          ),
        ],
      ),
    );
  }
}
