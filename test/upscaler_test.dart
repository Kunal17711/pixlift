import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixlift/core/constants.dart';
import 'package:pixlift/features/upscaler/data/pixel_ops.dart';
import 'package:pixlift/features/upscaler/data/tiling.dart';
import 'package:pixlift/features/upscaler/domain/upscale_types.dart';

void main() {
  group('TilePlanner', () {
    test('estimate keeps aspect ratio and caps output at maxOutputDim', () {
      final d = TilePlanner.estimate(1080, 1080, UpscaleMode.x4);
      expect(d.width, lessThanOrEqualTo(PixLiftConfig.maxOutputDim));
      expect(d.height, lessThanOrEqualTo(PixLiftConfig.maxOutputDim));
      expect(d.width, d.height);
    });

    test('4x of 720 square is exactly 2880 when under the cap', () {
      final d = TilePlanner.estimate(720, 720, UpscaleMode.x4);
      expect(d.width, 2880);
      expect(d.height, 2880);
    });

    test('4x of 720x1280 is exactly 2880x5120', () {
      final d = TilePlanner.estimate(720, 1280, UpscaleMode.x4);
      expect(d.width, 2880);
      expect(d.height, 5120);
    });

    test('2x of 1080x720 is 2160x1440', () {
      final d = TilePlanner.estimate(1080, 720, UpscaleMode.x2);
      expect(d.width, 2160);
      expect(d.height, 1440);
    });

    test('oversized sources scale down to fit the cap', () {
      final d = TilePlanner.estimate(5000, 3000, UpscaleMode.x4);
      expect(d.width, lessThanOrEqualTo(PixLiftConfig.maxOutputDim));
      expect(d.width / d.height, closeTo(5000 / 3000, 0.01));
    });

    test('output dims are multiples of the selected scale', () {
      for (final mode in UpscaleMode.values) {
        for (var w = 100; w <= 1500; w += 113) {
          for (var h = 80; h <= 900; h += 97) {
            final d = TilePlanner.estimate(w, h, mode);
            expect(d.width % mode.targetScale, 0,
                reason: '$w/$h ${mode.label}');
            expect(d.height % mode.targetScale, 0,
                reason: '$w/$h ${mode.label}');
          }
        }
      }
    });

    test('tile cores cover the output and model inputs stay bounded', () {
      final plan = TilePlanner.plan(1080, 720, UpscaleMode.x4);
      expect(plan.tiles, isNotEmpty);
      for (final t in plan.tiles) {
        expect(t.outW, greaterThan(0));
        expect(t.inW, lessThanOrEqualTo(PixLiftConfig.maxModelTile));
        expect(t.inH, lessThanOrEqualTo(PixLiftConfig.maxModelTile));
        expect(t.outX + t.outW, lessThanOrEqualTo(plan.outW));
        expect(t.outY + t.outH, lessThanOrEqualTo(plan.outH));
      }
      final maxY = plan.tiles
          .map((t) => t.outY + t.outH)
          .reduce((a, b) => a > b ? a : b);
      expect(maxY, plan.outH);
    });

    test('model input size equals output / 4', () {
      final plan = TilePlanner.plan(720, 720, UpscaleMode.x4);
      expect(plan.outW, plan.modelInW * 4);
      expect(plan.outH, plan.modelInH * 4);
    });
  });

  group('PixelOps', () {
    test('bilinearScaleRgba produces correct target size', () {
      final src = Uint8List(16 * 12 * 4);
      expect(PixelOps.bilinearScaleRgba(src, 16, 12, 8, 6).length, 8 * 6 * 4);
    });

    test('bilinear scale returns src when dims unchanged', () {
      final src = Uint8List(8 * 8 * 4);
      expect(
        identical(PixelOps.bilinearScaleRgba(src, 8, 8, 8, 8), src),
        isTrue,
      );
    });

    test('extractRgbaRegion copies the correct sub-region', () {
      final src = Uint8List(3 * 1 * 4);
      src[0] = 10;
      src[4] = 20;
      src[8] = 30;
      final r = PixelOps.extractRgbaRegion(src, 3, 1, 1, 0, 2, 1);
      expect(r.length, 2 * 1 * 4);
      expect(r[0], 20);
      expect(r[4], 30);
    });

    test('rgbaTileToNchwF32 lays out NCHW f32 LE in 0..1', () {
      final src = Uint8List(2 * 1 * 4);
      src[0] = 255; // R
      src[2] = 128; // B
      final bytes = PixelOps.rgbaTileToNchwF32(src, 2, 1, 0, 0, 2, 1);
      expect(bytes.length, 2 * 1 * 3 * 4);
      final bd = ByteData.sublistView(bytes);
      expect(bd.getFloat32(0, Endian.little), closeTo(1.0, 1e-6));
      expect(bd.getFloat32(4, Endian.little), closeTo(0.0, 1e-6));
      final blue = 2 * 2 * 4; // ch2 after R+G planes
      expect(bd.getFloat32(blue, Endian.little), closeTo(128 / 255, 1e-5));
    });

    test('copyTileCoreToStrip crops context and writes the exact core', () {
      final tileRgb = Uint8List(4 * 4 * 3);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          final offset = (y * 4 + x) * 3;
          tileRgb[offset] = x + y * 10;
          tileRgb[offset + 1] = 100;
          tileRgb[offset + 2] = 200;
        }
      }
      final strip = Uint8List(4 * 2 * 3);
      PixelOps.copyTileCoreToStrip(
        strip,
        4,
        const TileSpec(
          outX: 1,
          outY: 0,
          outW: 2,
          outH: 2,
          inX: 0,
          inY: 0,
          inW: 2,
          inH: 2,
          cropX: 1,
          cropY: 1,
        ),
        tileRgb,
        4,
        4,
      );
      expect(strip[(0 * 4 + 1) * 3], 11);
      expect(strip[(0 * 4 + 2) * 3], 12);
      expect(strip[(1 * 4 + 1) * 3], 21);
      expect(strip[(1 * 4 + 2) * 3], 22);
    });
  });
}
