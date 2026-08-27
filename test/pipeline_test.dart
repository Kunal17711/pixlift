import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixlift/core/pixlift_error.dart';
import 'package:pixlift/features/upscaler/data/upscale_pipeline.dart';
import 'package:pixlift/features/upscaler/domain/upscale_types.dart';

import 'support/fake_onnx_engine.dart';

void main() {
  SelectedImage makeImg(int w, int h) {
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 255;
      rgba[i + 1] = 0;
      rgba[i + 2] = 0;
      rgba[i + 3] = 255;
    }
    return SelectedImage(
      path: '/tmp/test.jpg',
      name: 'test.jpg',
      width: w,
      height: h,
      rgba: rgba,
    );
  }

  late Directory cache;
  setUp(() async {
    cache = await Directory.systemTemp.createTemp('pixlift_pipe_');
  });
  tearDown(() => cache.delete(recursive: true));

  test('4x pipeline stitches tiles into the correct output dims', () async {
    final engine = FakeOnnxEngine();
    final pipe = UpscalePipeline(engine: engine, cacheDir: cache);
    var last = UpscaleProgress(done: 0, total: 0);
    final res = await pipe.process(
      makeImg(300, 200),
      UpscaleMode.x4,
      onProgress: (d, t) => last = UpscaleProgress(done: d, total: t),
    );
    expect(res.width, 1200);
    expect(res.height, 800);
    expect(engine.tileCalls, 6);
    expect(File(res.outputPath).existsSync(), isTrue);
    expect(File(res.previewPath).existsSync(), isTrue);
    expect(last.done, last.total);
  });

  test('2x pipeline runs the real 4x model at source scale', () {
    final engine = FakeOnnxEngine();
    final pipe = UpscalePipeline(engine: engine, cacheDir: cache);
    final plan = pipe.planFor(makeImg(400, 300), UpscaleMode.x2);
    expect(plan.modelInW, 400);
    expect(plan.modelInH, 300);
    expect(plan.outW, 800);
    expect(plan.outH, 600);
  });

  test('2x pipeline produces the exact requested dimensions', () async {
    final engine = FakeOnnxEngine();
    final pipe = UpscalePipeline(engine: engine, cacheDir: cache);
    final res = await pipe.process(makeImg(80, 60), UpscaleMode.x2);
    expect(res.width, 160);
    expect(res.height, 120);
    expect(File(res.outputPath).existsSync(), isTrue);
  });

  test('cancellation aborts before inference', () async {
    final engine = FakeOnnxEngine();
    final pipe = UpscalePipeline(engine: engine, cacheDir: cache);
    expect(
      () => pipe.process(
        makeImg(300, 200),
        UpscaleMode.x4,
        isCancelled: () => true,
      ),
      throwsA(isA<UpscaleCancelledException>()),
    );
    expect(engine.tileCalls, 0);
  });

  test('model load failure surfaces a friendly exception', () async {
    final engine = FakeOnnxEngine()..failInit = true;
    final pipe = UpscalePipeline(engine: engine, cacheDir: cache);
    expect(
      () => pipe.process(makeImg(300, 200), UpscaleMode.x4),
      throwsA(isA<PixLiftException>()),
    );
  });
}
