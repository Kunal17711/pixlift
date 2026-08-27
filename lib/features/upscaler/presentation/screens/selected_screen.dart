import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/brand_colors.dart';
import '../../../../widgets/primary_button.dart';
import '../../domain/upscale_types.dart';
import '../upscale_controller.dart';

/// Photo picked: choose 2x / 4x, see honest final dimensions, then Upscale.
class SelectedScreen extends StatelessWidget {
  const SelectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpscaleController>();
    final img = controller.image;
    if (img == null) return const SizedBox.shrink();
    final dims = controller.estimatedDims;
    final error = controller.errorMessage;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to home',
          onPressed: controller.pickAnother,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Your photo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo preview.
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: img.originalWidth / img.originalHeight,
                  child: Container(
                    color: const Color(0xFF0B1226),
                    child: Image.file(
                      File(img.path),
                      fit: BoxFit.contain,
                      cacheWidth: 1600,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stack) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Upscale size choice.
              Text('How big?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SegmentedButton<UpscaleMode>(
                segments: const [
                  ButtonSegment(
                    value: UpscaleMode.x2,
                    label: Text('2×'),
                    icon: Icon(Icons.photo_size_select_small),
                  ),
                  ButtonSegment(
                    value: UpscaleMode.x4,
                    label: Text('4×'),
                    icon: Icon(Icons.photo_size_select_large),
                  ),
                ],
                selected: {controller.mode},
                onSelectionChanged: (s) => controller.setMode(s.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Honest final dimensions.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${img.originalWidth} × ${img.originalHeight}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: BrandColors.cyan,
                    ),
                    Text(
                      '${dims.width} × ${dims.height}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.brandBlue,
                      ),
                    ),
                  ],
                ),
              ),

              if (dims.width !=
                      img.originalWidth * controller.mode.targetScale ||
                  dims.height !=
                      img.originalHeight * controller.mode.targetScale) ...[
                const SizedBox(height: 10),
                const Text(
                  'This large photo will be scaled safely to fit your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: BrandColors.textMutedDark,
                  ),
                ),
              ],

              if (controller.mode == UpscaleMode.x4) ...[
                const SizedBox(height: 10),
                const Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: BrandColors.textMutedDark,
                    ),
                    Text(
                      '4× takes a little longer on some phones.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: BrandColors.textMutedDark,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Upscale',
                icon: Icons.auto_fix_high_rounded,
                onPressed: controller.start,
              ),

              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const SizedBox(height: 12),
              TextButton(
                onPressed: controller.pickPhoto,
                child: const Text('Choose another photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
