import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../core/pixlift_error.dart';
import '../../../services/onnx_engine.dart';
import '../domain/upscale_types.dart';
import 'pixel_ops.dart';
import 'tiling.dart';

/// Orchestrates: bounded pre-scale -> context-aware tiled AI inference ->
/// disk-backed stitching -> native PNG/JPEG encode.
///
/// Heavy model inference is always delegated to the native background thread;
/// the pure-Dart pre-scale runs in a background isolate. The tile loop itself
/// only performs light per-tile math between awaited channel calls, so the UI
/// stays responsive and the event loop keeps turning.
class UpscalePipeline {
  UpscalePipeline({required this.engine, required this.cacheDir});

  final OnnxEngine engine;
  final Directory cacheDir;

  /// Full plan (out dims, tiles) — cheap, callable before processing starts.
  UpscalePlan planFor(SelectedImage image, UpscaleMode mode) =>
      TilePlanner.plan(image.originalWidth, image.originalHeight, mode);

  Future<UpscaleResult> process(
    SelectedImage image,
    UpscaleMode mode, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final cancel = isCancelled ?? () => false;
    final plan = planFor(image, mode);
    await engine.ensureInitialized();
    if (cancel()) throw UpscaleCancelledException();

    // 1) Prepare the exact model input in a background isolate. For uncapped
    // images this is the orientation-correct source size. Large sources are
    // uniformly reduced according to the honest dimensions shown in the UI.
    Uint8List modelInput;
    if (plan.modelInW != image.width || plan.modelInH != image.height) {
      modelInput = await Isolate.run(
        () => PixelOps.bilinearScaleRgba(
          image.rgba,
          image.width,
          image.height,
          plan.modelInW,
          plan.modelInH,
        ),
      );
    } else {
      modelInput = image.rgba;
    }
    if (cancel()) throw UpscaleCancelledException();

    // 2) Tiled inference + disk-backed stitching. One full-width strip is
    // retained at a time; no full-resolution RGBA output exists in Dart.
    final jobDir = await _jobDir();
    final rawPath = '${jobDir.path}/final.rgb';
    final format = _preferredFormat(image.name);
    final outPath = '${cacheDir.path}/${_fileName(format)}';
    var completed = false;
    try {
      final raw = await File(rawPath).open(mode: FileMode.write);
      try {
        var done = 0;
        var index = 0;
        final total = plan.tiles.length;
        while (index < total) {
          final rowY = plan.tiles[index].outY;
          final rowH = plan.tiles[index].outH;
          final strip = Uint8List(plan.outW * rowH * 3);
          while (index < total && plan.tiles[index].outY == rowY) {
            if (cancel()) throw UpscaleCancelledException();
            final tile = plan.tiles[index];
            final region = PixelOps.extractRgbaRegion(
              modelInput,
              plan.modelInW,
              plan.modelInH,
              tile.inX,
              tile.inY,
              tile.inW,
              tile.inH,
            );
            final nchw = PixelOps.rgbaTileToNchwF32(
              region,
              tile.inW,
              tile.inH,
              0,
              0,
              tile.inW,
              tile.inH,
            );
            final rgbPath = '${jobDir.path}/tile_$done.rgb';
            final tileResult = await engine.upscaleTile(
              nchw,
              tile.inH,
              tile.inW,
              mode.targetScale,
              rgbPath,
            );
            final expectedW = tile.inW * mode.targetScale;
            final expectedH = tile.inH * mode.targetScale;
            if (tileResult.outW != expectedW || tileResult.outH != expectedH) {
              throw PixLiftException(
                PixLiftErrorKind.inferenceFailed,
                'The AI model returned an unexpected image size.',
                '${tileResult.outW}x${tileResult.outH}, expected ${expectedW}x$expectedH',
              );
            }
            final tileFile = File(rgbPath);
            final tileRgb = await tileFile.readAsBytes();
            PixelOps.copyTileCoreToStrip(
              strip,
              plan.outW,
              tile,
              tileRgb,
              tileResult.outW,
              tileResult.outH,
            );
            await tileFile.delete();
            done++;
            index++;
            onProgress?.call(done, total);
          }
          await raw.writeFrom(strip);
        }
        await raw.flush();
      } finally {
        await raw.close();
      }

      if (cancel()) throw UpscaleCancelledException();
      await engine.encodeImage(
        rawPath: rawPath,
        w: plan.outW,
        h: plan.outH,
        format: format,
        quality: format == 'jpg' ? 96 : 100,
        outPath: outPath,
      );
      completed = true;
      return UpscaleResult(
        width: plan.outW,
        height: plan.outH,
        mode: mode,
        outputPath: outPath,
        // Flutter's decoder honors cacheWidth on the result screen, so the
        // encoded output itself is also the memory-bounded preview source.
        previewPath: outPath,
        format: format,
      );
    } finally {
      if (!completed) {
        final partial = File(outPath);
        if (partial.existsSync()) partial.deleteSync();
      }
      if (jobDir.existsSync()) await jobDir.delete(recursive: true);
    }
  }

  Future<Directory> _jobDir() async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final dir = Directory('${cacheDir.path}/job_$id');
    await dir.create(recursive: true);
    return dir;
  }

  static String _preferredFormat(String name) =>
      name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';

  String _fileName(String ext) {
    final d = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts =
        '${d.year}${two(d.month)}${two(d.day)}_'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}';
    final micros = d.microsecond.toString().padLeft(6, '0');
    return 'PixLift_${ts}_$micros.$ext';
  }
}

/// Helper so tests can locate the cache dir without a device.
Future<Directory> getCacheDir() async {
  final dir = await getTemporaryDirectory();
  final c = Directory('${dir.path}/pixlift');
  if (!c.existsSync()) await c.create(recursive: true);
  return c;
}
