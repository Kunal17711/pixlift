/// Global PixLift configuration constants.
class PixLiftConfig {
  PixLiftConfig._();

  static const String appName = 'PixLift';
  static const String tagline = 'Give those pixels a glow-up.';
  static const String supportLine =
      'Turn low-res photos into crisp, high-resolution images.';
  static const String trustLine = 'On-device • No watermark • Free';
  static const String builderLine = 'Built by Kunal Builds';
  static const String brandHandle = '@bykunalbuilds';
  static const String instagramUrl = 'https://instagram.com/bykunalbuilds';

  /// Bundled ONNX model (Real-ESRGAN realesr-general-x4v3, BSD-3-Clause).
  static const String modelAssetKey = 'assets/model/realesr-general-x4v3.onnx';
  static const String modelSha256 =
      '560b2e93418a61fbbf1eeeefeee6496c7dbe769333e9b151645e7164312c7b7b';

  /// The bundled model always upscales by 4x. The 2x mode runs the same
  /// network and produces the requested 2x dimensions from its output.
  static const int modelScale = 4;

  /// Safety limits. A 720 × 1280 image still produces the exact requested
  /// 2880 × 5120 result in 4× mode, while very large camera photos are scaled
  /// uniformly to avoid creating a bitmap that can exhaust a phone's heap.
  static const int maxOutputDim = 8192;
  static const int maxOutputPixels = 16 * 1000 * 1000;

  /// Bound the decoded working buffer independently from the source metadata.
  /// Output dimensions continue to be calculated from the real source size.
  static const int maxDecodeDim = 4096;
  static const int maxDecodePixels = 16 * 1000 * 1000;

  // ---- Tiling (model-input space) ----
  // Each inference tile is at most 192×192 pixels. Thirty-six pixels of
  // context cover the compact model's 34-pixel convolutional receptive radius
  // on every internal edge, preventing zero-padding
  // artifacts from becoming visible seams without retaining a full output
  // bitmap in Dart memory.
  static const int maxModelTile = 192;
  static const int tileContext = 36;

  // ---- Copy ----
  static const String processingLine = 'Lifting those pixels…';
  static const String privacyLine = 'Everything stays on your device.';
}
