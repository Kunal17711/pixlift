import 'dart:math' as math;

import '../../../core/constants.dart';
import '../domain/upscale_types.dart';

/// Decides output dimensions and the tile grid for one image + mode.
///
/// The model always produces 4x output. For 2x mode we target 2x dimensions:
/// the model runs on a half-size input so its native output is exactly the
/// requested 2x size — no double resampling of real pixels.
class TilePlanner {
  TilePlanner._();

  /// Output dimensions for a source image in the given mode.
  static ({int width, int height}) estimate(
    int srcW,
    int srcH,
    UpscaleMode mode,
  ) {
    final plan = _dimensions(srcW, srcH, mode);
    return (width: plan.$3, height: plan.$4);
  }

  static UpscalePlan plan(int srcW, int srcH, UpscaleMode mode) {
    final dims = _dimensions(srcW, srcH, mode);
    final modelInW = dims.$1;
    final modelInH = dims.$2;
    final outW = dims.$3;
    final outH = dims.$4;
    final scale = mode.targetScale;
    final coreInput =
        PixLiftConfig.maxModelTile - 2 * PixLiftConfig.tileContext;
    final coreOut = coreInput * scale;

    final tiles = <TileSpec>[];
    for (var y = 0; y < outH; y += coreOut) {
      final coreH = (outH - y).clamp(1, coreOut).toInt();
      final coreInTop = y ~/ scale;
      final coreInBottom = (y + coreH) ~/ scale;
      final inY = (coreInTop - PixLiftConfig.tileContext)
          .clamp(0, modelInH)
          .toInt();
      final inBottom = (coreInBottom + PixLiftConfig.tileContext)
          .clamp(0, modelInH)
          .toInt();
      for (var x = 0; x < outW; x += coreOut) {
        final coreW = (outW - x).clamp(1, coreOut).toInt();
        final coreInLeft = x ~/ scale;
        final coreInRight = (x + coreW) ~/ scale;
        final inX = (coreInLeft - PixLiftConfig.tileContext)
            .clamp(0, modelInW)
            .toInt();
        final inRight = (coreInRight + PixLiftConfig.tileContext)
            .clamp(0, modelInW)
            .toInt();
        tiles.add(
          TileSpec(
            outX: x,
            outY: y,
            outW: coreW,
            outH: coreH,
            inX: inX,
            inY: inY,
            inW: inRight - inX,
            inH: inBottom - inY,
            cropX: (coreInLeft - inX) * scale,
            cropY: (coreInTop - inY) * scale,
          ),
        );
      }
    }

    return UpscalePlan(
      srcW: srcW,
      srcH: srcH,
      modelInW: modelInW,
      modelInH: modelInH,
      outW: outW,
      outH: outH,
      mode: mode,
      tiles: tiles,
    );
  }

  static (int, int, int, int) _dimensions(
    int srcW,
    int srcH,
    UpscaleMode mode,
  ) {
    final target = mode.targetScale.toDouble();
    final byW = PixLiftConfig.maxOutputDim / srcW;
    final byH = PixLiftConfig.maxOutputDim / srcH;
    final byPixels = math.sqrt(PixLiftConfig.maxOutputPixels / (srcW * srcH));
    var q = target < byW ? target : byW;
    if (byH < q) q = byH;
    if (byPixels < q) q = byPixels;
    final scale = mode.targetScale;
    final modelInW = (srcW * q / scale)
        .round()
        .clamp(1, PixLiftConfig.maxOutputDim ~/ scale)
        .toInt();
    final modelInH = (srcH * q / scale)
        .round()
        .clamp(1, PixLiftConfig.maxOutputDim ~/ scale)
        .toInt();
    return (modelInW, modelInH, modelInW * scale, modelInH * scale);
  }
}
