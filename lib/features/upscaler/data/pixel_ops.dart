import 'dart:typed_data';

import '../domain/upscale_types.dart' show TileSpec;

/// Pure pixel math shared by the upscale pipeline. All functions are pure,
/// allocation-light and unit-testable.
class PixelOps {
  PixelOps._();

  static int rgbaIndex(int x, int y, int stride) => (y * stride + x) * 4;

  /// Nearest-neighbor copy of a region from an RGBA source.
  static Uint8List extractRgbaRegion(
    Uint8List src,
    int srcW,
    int srcH,
    int x,
    int y,
    int w,
    int h,
  ) {
    final out = Uint8List(w * h * 4);
    final xC = x.clamp(0, srcW);
    final yC = y.clamp(0, srcH);
    final maxY = (yC + h).clamp(0, srcH);
    final maxX = (xC + w).clamp(0, srcW);
    for (var row = 0; row < h; row++) {
      final srcY = y + row;
      if (srcY < yC || srcY >= maxY) continue;
      final srcBase = rgbaIndex(xC, srcY, srcW);
      final dstBase = row * w * 4;
      for (var col = 0; col < w; col++) {
        final srcX = x + col;
        if (srcX < xC || srcX >= maxX) continue;
        final so = srcBase + (srcX - xC) * 4;
        final doff = dstBase + col * 4;
        out[doff] = src[so];
        out[doff + 1] = src[so + 1];
        out[doff + 2] = src[so + 2];
        out[doff + 3] = src[so + 3];
      }
    }
    return out;
  }

  /// Bilinear scale of an RGBA image to dstW x dstH.
  static Uint8List bilinearScaleRgba(
    Uint8List src,
    int srcW,
    int srcH,
    int dstW,
    int dstH,
  ) {
    if (dstW == srcW && dstH == srcH) return src;
    if (dstW <= 0 || dstH <= 0) return Uint8List(0);
    final out = Uint8List(dstW * dstH * 4);
    final xRatio = srcW / dstW;
    final yRatio = srcH / dstH;
    for (var dy = 0; dy < dstH; dy++) {
      final srcY = dy * yRatio;
      final y0 = srcY.floor().clamp(0, srcH - 1);
      final y1 = (y0 + 1).clamp(0, srcH - 1);
      final fy = srcY - y0;
      for (var dx = 0; dx < dstW; dx++) {
        final srcX = dx * xRatio;
        final x0 = srcX.floor().clamp(0, srcW - 1);
        final x1 = (x0 + 1).clamp(0, srcW - 1);
        final fx = srcX - x0;
        final dst = rgbaIndex(dx, dy, dstW);
        final tl = rgbaIndex(x0, y0, srcW);
        final tr = rgbaIndex(x1, y0, srcW);
        final bl = rgbaIndex(x0, y1, srcW);
        final br = rgbaIndex(x1, y1, srcW);
        for (var c = 0; c < 4; c++) {
          final a = src[tl + c].toDouble();
          final b = src[tr + c].toDouble();
          final d = src[bl + c].toDouble();
          final e = src[br + c].toDouble();
          final top = a + (b - a) * fx;
          final bottom = d + (e - d) * fx;
          out[dst + c] = (top + (bottom - top) * fy).round().clamp(0, 255);
        }
      }
    }
    return out;
  }

  /// Converts one RGBA tile into NCHW float32 little-endian (model input).
  /// Values are normalized into [0, 1] like the Real-ESRGAN pipeline.
  static Uint8List rgbaTileToNchwF32(
    Uint8List rgba,
    int srcW,
    int srcH,
    int x,
    int y,
    int w,
    int h,
  ) {
    final n = w * h;
    final bytes = ByteData(n * 3 * 4);
    var o = 0;
    final xC = x.clamp(0, srcW);
    final yC = y.clamp(0, srcH);
    final maxY = (yC + h).clamp(0, srcH);
    final maxX = (xC + w).clamp(0, srcW);
    for (var c = 0; c < 3; c++) {
      for (var py = 0; py < h; py++) {
        final srcY = y + py;
        final base = (srcY >= yC && srcY < maxY)
            ? rgbaIndex(xC, srcY, srcW) + c
            : -4;
        for (var px = 0; px < w; px++) {
          final srcX = x + px;
          final v = (srcX >= xC && srcX < maxX && base >= 0)
              ? rgba[base + (srcX - xC) * 4]
              : 0;
          bytes.setFloat32(o, v / 255.0, Endian.little);
          o += 4;
        }
      }
    }
    return bytes.buffer.asUint8List();
  }

  /// Copies the context-free core of an interleaved RGB inference tile into
  /// a full-width output strip. Tile cores never overlap, so every output
  /// pixel is written exactly once after being inferred with neighbour
  /// context.
  static void copyTileCoreToStrip(
    Uint8List strip,
    int stripW,
    TileSpec tile,
    Uint8List tileRgb,
    int tileW,
    int tileH,
  ) {
    assert(tile.cropX + tile.outW <= tileW);
    assert(tile.cropY + tile.outH <= tileH);
    assert(tileRgb.length == tileW * tileH * 3);
    for (var row = 0; row < tile.outH; row++) {
      final src = ((tile.cropY + row) * tileW + tile.cropX) * 3;
      final dst = (row * stripW + tile.outX) * 3;
      strip.setRange(dst, dst + tile.outW * 3, tileRgb, src);
    }
  }
}
