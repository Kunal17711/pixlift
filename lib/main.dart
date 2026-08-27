import 'package:flutter/material.dart';

import 'app.dart';
import 'services/model_warmup.dart';
import 'services/onnx_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final engine = OnnxEngine();
  runApp(PixLiftApp(engine: engine));
  // Start the AI model warm-up right after the first frame so the app opens
  // instantly and inference is ready by the time the user finishes picking.
  ModelWarmup.begin(engine);
}
