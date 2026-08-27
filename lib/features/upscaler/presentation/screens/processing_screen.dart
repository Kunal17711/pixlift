import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants.dart';
import '../../../../theme/brand_colors.dart';
import '../upscale_controller.dart';

/// Processing state: alive, premium, honest.
///
/// The progress bar is REAL — it tracks AI tiles actually completed.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpscaleController>();
    final img = controller.image;
    final progress = controller.progress;
    final error = controller.errorMessage;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BrandColors.deepGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Center(
                        child: SizedBox(
                          width: 250,
                          height: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Breathing glow ring.
                              AnimatedBuilder(
                                animation: _pulse,
                                builder: (context, _) {
                                  final t = _pulse.value;
                                  return Container(
                                    width: 212 + 40 * t,
                                    height: 212 + 40 * t,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          BrandColors.cyan.withValues(
                                            alpha: 0.35 * (1 - t) + 0.1,
                                          ),
                                          BrandColors.brandBlue.withValues(
                                            alpha: 0.18 * (1 - t),
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ClipOval(
                                child: img != null
                                    ? Image.file(
                                        File(img.path),
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        cacheWidth: 800,
                                      )
                                    : Container(
                                        width: 200,
                                        height: 200,
                                        color: Colors.white10,
                                        child: const Icon(
                                          Icons.auto_fix_high_rounded,
                                          size: 80,
                                          color: Colors.white24,
                                        ),
                                      ),
                              ),
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: BrandColors.cyan.withValues(
                                      alpha: 0.45,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 44),
                      const Text(
                        'Lifting those pixels…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        PixLiftConfig.privacyLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: BrandColors.textMutedDark,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 14),
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
                      if (progress.total > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress.fraction,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            color: BrandColors.cyan,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${progress.done} / ${progress.total} tiles done',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: BrandColors.textMutedDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: controller.cancelProcessing,
                          child: const Text(
                            'Stop',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
