import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/brand_colors.dart';
import '../../../../widgets/primary_button.dart';
import '../upscale_controller.dart';
import '../widgets/compare_slider.dart';

/// The money screen: before/after comparison with a smooth draggable divider
/// and pinch-to-zoom, real dimensions, then Save / Share / Pick another.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpscaleController>();
    final img = controller.image;
    final res = controller.result;
    if (img == null || res == null) return const SizedBox.shrink();

    final aspect = res.width / res.height;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: controller.pickAnother,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Nice glow-up.'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                  ),
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: CompareSlider(
                      aspectRatio: aspect,
                      before: Image.file(
                        File(img.path),
                        fit: BoxFit.cover,
                        cacheWidth: 1600,
                        filterQuality: FilterQuality.low,
                      ),
                      after: Image.file(
                        File(res.previewPath),
                        fit: BoxFit.cover,
                        cacheWidth: 1600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Drag to compare · pinch to zoom',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Dimensions.
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
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
                      '${res.width} × ${res.height}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.brandBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Save',
                      icon: Icons.download_rounded,
                      onPressed: controller.saveToGallery,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: controller.share,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: controller.pickPhoto,
                child: const Text('Upscale another photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
