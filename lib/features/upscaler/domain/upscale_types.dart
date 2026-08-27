import 'dart:typed_data';

/// Quality / output-size option for the single upscaling feature.
enum UpscaleMode {
  x2(2),
  x4(4);

  const UpscaleMode(this.targetScale);
  final int targetScale;

  String get label => '$targetScale×';
}

/// A photo picked by the user, decoded and EXIF-normalized with a bounded
/// memory footprint (dims capped at [PixLiftConfig.maxDecodeDim]).
class SelectedImage {
  const SelectedImage({
    required this.path,
    required this.name,
    required this.width,
    required this.height,
    required this.rgba,
    int? originalWidth,
    int? originalHeight,
  }) : originalWidth = originalWidth ?? width,
       originalHeight = originalHeight ?? height;

  final String path;
  final String name;
  final int width;
  final int height;
  final int originalWidth;
  final int originalHeight;

  /// Raw RGBA8888 bytes, orientation already applied by the image codec.
  final Uint8List rgba;

  int get pixelCount => width * height;
  int get originalPixelCount => originalWidth * originalHeight;
}

/// Position + size of one tile, expressed in output (post-upscale) space.
class TileSpec {
  const TileSpec({
    required this.outX,
    required this.outY,
    required this.outW,
    required this.outH,
    required this.inX,
    required this.inY,
    required this.inW,
    required this.inH,
    required this.cropX,
    required this.cropY,
  });

  final int outX;
  final int outY;
  final int outW;
  final int outH;

  /// Context-inclusive region read from the model input.
  final int inX;
  final int inY;

  /// Model input size (outW / 4 rounded to a multiple of 4).
  final int inW;
  final int inH;

  /// Offset of the non-overlapping core inside the inferred tile output.
  final int cropX;
  final int cropY;

  int get modelPixels => inW * inH;
}

/// Strategy chosen for one image: output dimensions, model input dimensions
/// and the tile grid. Tiles overlap by [PixLiftConfig.overlapOut] pixels and
/// are feather-blended during stitching.
class UpscalePlan {
  const UpscalePlan({
    required this.srcW,
    required this.srcH,
    required this.modelInW,
    required this.modelInH,
    required this.outW,
    required this.outH,
    required this.mode,
    required this.tiles,
  });

  final int srcW;
  final int srcH;
  final int modelInW;
  final int modelInH;
  final int outW;
  final int outH;
  final UpscaleMode mode;
  final List<TileSpec> tiles;

  int get tileCount => tiles.length;
}

/// A finished upscale, saved on device as an image file.
class UpscaleResult {
  const UpscaleResult({
    required this.width,
    required this.height,
    required this.mode,
    required this.outputPath,
    required this.previewPath,
    required this.format,
  });

  final int width;
  final int height;
  final UpscaleMode mode;
  final String outputPath;
  final String previewPath;
  final String format; // 'png' | 'jpg'

  String get fileName => outputPath.split('/').last;
}

/// Genuine measurable progress (tiles completed / total).
class UpscaleProgress {
  const UpscaleProgress({required this.done, required this.total});
  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
  bool get isComplete => done >= total;
}
