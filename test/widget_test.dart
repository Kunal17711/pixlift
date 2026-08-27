import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixlift/features/upscaler/domain/upscale_types.dart';
import 'package:pixlift/features/upscaler/presentation/upscale_controller.dart';
import 'package:pixlift/features/upscaler/presentation/screens/result_screen.dart';
import 'package:pixlift/features/upscaler/presentation/screens/selected_screen.dart';
import 'package:pixlift/features/upscaler/presentation/widgets/compare_slider.dart';
import 'package:pixlift/core/constants.dart';
import 'package:pixlift/app.dart';
import 'package:pixlift/services/media_saver.dart';
import 'package:pixlift/services/photo_picker.dart';
import 'package:pixlift/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'support/fake_onnx_engine.dart';

class _FakePicker implements PhotoPicker {
  _FakePicker(this.image);
  final SelectedImage? image;
  int calls = 0;
  @override
  Future<SelectedImage?> pickPhoto() async {
    calls++;
    return image;
  }
}

class _FakeSaver implements MediaSaver {
  int saves = 0;
  int shares = 0;
  @override
  Future<void> saveToGallery({
    required String srcPath,
    required String displayName,
    required String mime,
  }) async {
    saves++;
  }

  @override
  Future<void> shareFile(String path, {String? subject}) async {
    shares++;
  }
}

SelectedImage buildTestImage(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < rgba.length; i += 4) {
    rgba[i] = 255;
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

Future<UpscaleController> pumpApp(
  WidgetTester tester,
  FakeOnnxEngine engine,
  PhotoPicker picker,
  MediaSaver saver,
) async {
  final cache = Directory('${Directory.current.path}/build/widget_test_cache');
  if (!cache.existsSync()) cache.createSync(recursive: true);
  final ctrl = UpscaleController(
    engine: engine,
    picker: picker,
    saver: saver,
    cacheDirOverride: cache,
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: ctrl,
      child: Builder(
        builder: (_) => MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const FlowShell(),
        ),
      ),
    ),
  );
  return ctrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home / flow (fake services)', () {
    testWidgets('home renders CTA and brand, no overflow', (tester) async {
      final engine = FakeOnnxEngine();
      await pumpApp(tester, engine, _FakePicker(null), _FakeSaver());
      expect(find.text('Pick a photo'), findsOneWidget);
      expect(find.text(PixLiftConfig.tagline), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flow: pick -> selected -> upscale -> result', (tester) async {
      final engine = FakeOnnxEngine();
      final picker = _FakePicker(buildTestImage(40, 30));
      final saver = _FakeSaver();
      final controller = await pumpApp(tester, engine, picker, saver);

      await tester.tap(find.text('Pick a photo'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectedScreen), findsOneWidget);
      expect(find.text('Upscale'), findsOneWidget);

      await tester.ensureVisible(find.text('Upscale'));
      await tester.pumpAndSettle();
      await tester.runAsync(controller.start);
      await tester.pump();
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saver.saves, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('model load failure leaves an error notice, no result', (
      tester,
    ) async {
      final engine = FakeOnnxEngine()..failInit = true;
      final picker = _FakePicker(buildTestImage(200, 200));
      final controller = await pumpApp(tester, engine, picker, _FakeSaver());

      await tester.tap(find.text('Pick a photo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Upscale'));
      await tester.pumpAndSettle();
      await tester.runAsync(controller.start);
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsNothing);
      expect(find.textContaining('could not'), findsWidgets);
    });
  });

  group('CompareSlider', () {
    testWidgets('dragging and pinching do not throw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: CompareSlider(
                before: Container(color: Colors.red),
                after: Container(color: Colors.green),
                aspectRatio: 4 / 3,
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.createGesture();
      await gesture.down(Offset.zero);
      await gesture.moveTo(Offset(200, 150));
      expect(tester.takeException(), isNull);
      final g2 = await tester.createGesture();
      await g2.down(Offset.zero);
      await g2.moveTo(Offset(250, 150));
      await gesture.moveTo(Offset(300, 150));
      expect(tester.takeException(), isNull);
      await gesture.up();
      await g2.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });
}
