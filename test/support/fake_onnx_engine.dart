import 'dart:io';
import 'dart:typed_data';

import 'package:pixlift/core/pixlift_error.dart';
import 'package:pixlift/services/onnx_engine.dart';

/// Deterministic stand-in for the native ONNX bridge, used in tests to
/// exercise the *real* Dart pipeline (tiling, stitching, encoding, progress).
///
/// The "inference" is a nearest-neighbour 4x upscale of the tile, which lets
/// tests verify dimensions, seam blending and file flow end-to-end.
class FakeOnnxEngine implements OnnxEngine {
  int tileCalls = 0;
  int encodeCalls = 0;
  bool failInit = false;
  bool failInference = false;

  @override
  bool get ready => !failInit;

  @override
  Future<void> ensureInitialized() async {
    if (failInit) {
      throw PixLiftException(
        PixLiftErrorKind.modelLoadFailed,
        'The AI model could not be loaded on this device.',
        'fake',
      );
    }
  }

  @override
  Future<TileRunResult> upscaleTile(
    Uint8List inputChw,
    int h,
    int w,
    int scale,
    String outPath,
  ) async {
    tileCalls++;
    if (failInference) {
      throw PixLiftException(
        PixLiftErrorKind.inferenceFailed,
        'Something went wrong while lifting these pixels.',
        'fake',
      );
    }
    // Decode NCHW f32 LE; nearest-neighbour into interleaved RGB bytes.
    final bd = ByteData.sublistView(inputChw);
    final n = w * h;
    final outH = h * scale;
    final outW = w * scale;
    final outN = outH * outW;
    final planar = Uint8List(outN * 3);
    for (var py = 0; py < outH; py++) {
      final sy = (py ~/ scale) * w;
      for (var px = 0; px < outW; px++) {
        final sx = px ~/ scale;
        final srcByte = (sy + sx) * 4;
        final outByte = (py * outW + px) * 3;
        for (var c = 0; c < 3; c++) {
          final v = bd.getFloat32(c * n * 4 + srcByte, Endian.little);
          planar[outByte + c] = (v * 255.0).round().clamp(0, 255);
        }
      }
    }
    File(outPath).writeAsBytesSync(planar);
    return TileRunResult(outH: outH, outW: outW);
  }

  @override
  Future<void> encodeImage({
    required String rawPath,
    required int w,
    required int h,
    required String format,
    required int quality,
    required String outPath,
  }) async {
    encodeCalls++;
    // Simulated encoded output (tests only need the file to exist).
    File(
      outPath,
    ).writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47, w & 0xff, h & 0xff]);
  }

  @override
  Future<void> dispose() async {}
}
