import 'dart:async';

import 'onnx_engine.dart';

/// Warms up the AI model in the background right after the first frame so the
/// app feels instant. The core upscale flow also awaits [OnnxEngine.init] with
/// the same single-flight session, so user action is never blocked twice.
class ModelWarmup {
  ModelWarmup._();

  static Future<void>? _task;

  static void begin(OnnxEngine engine) {
    _task ??= _warm(engine);
  }

  static Future<void> _warm(OnnxEngine engine) async {
    // Let the first frame paint before touching the native side.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    try {
      await engine.ensureInitialized();
    } catch (_) {
      // Model load is retried lazily by the controller when the user starts
      // an upscale, so a busy-device failure here is non-fatal.
    }
  }
}
