import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/upscaler/presentation/screens/home_screen.dart';
import 'features/upscaler/presentation/screens/processing_screen.dart';
import 'features/upscaler/presentation/screens/result_screen.dart';
import 'features/upscaler/presentation/screens/selected_screen.dart';
import 'features/upscaler/presentation/upscale_controller.dart';
import 'services/media_saver.dart';
import 'services/onnx_engine.dart';
import 'services/photo_picker.dart';
import 'theme/app_theme.dart';

/// Root of the PixLift Flutter app.
class PixLiftApp extends StatelessWidget {
  const PixLiftApp({super.key, required this.engine});

  final OnnxEngine engine;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UpscaleController>(
      create: (_) => UpscaleController(
        engine: engine,
        picker: PhotoPicker(),
        saver: MediaSaver(),
      ),
      child: MaterialApp(
        title: 'PixLift',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const FlowShell(),
      ),
    );
  }
}

/// Switches between the four stages of the single upscale flow and surfaces
/// one-shot notices (success / error) as snack bars.
class FlowShell extends StatefulWidget {
  const FlowShell({super.key});

  @override
  State<FlowShell> createState() => _FlowShellState();
}

class _FlowShellState extends State<FlowShell> {
  int _lastNotice = 0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpscaleController>();
    if (controller.noticeId != _lastNotice) {
      _lastNotice = controller.noticeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = context.read<UpscaleController>();
        final text = c.message ?? c.errorMessage;
        if (text != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(text),
              backgroundColor: c.errorMessage != null
                  ? const Color(0xFFB3261E)
                  : null,
            ),
          );
        }
      });
    }

    return switch (controller.stage) {
      UiStage.selected => const SelectedScreen(),
      UiStage.processing => const ProcessingScreen(),
      UiStage.result => const ResultScreen(),
      UiStage.home => const HomeScreen(),
    };
  }
}
