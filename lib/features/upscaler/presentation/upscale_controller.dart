import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/pixlift_error.dart';
import '../../../services/media_saver.dart';
import '../../../services/onnx_engine.dart';
import '../../../services/photo_picker.dart';
import '../data/tiling.dart';
import '../data/upscale_pipeline.dart';
import '../domain/upscale_types.dart';

/// Current UI stage of the single upscale flow.
enum UiStage { home, selected, processing, result }

/// Screen/flow state + business flow for PixLift.
///
/// Keeps images and the model session alive across screens, guards against
/// duplicate simultaneous runs, and never shows stale results.
class UpscaleController extends ChangeNotifier {
  UpscaleController({
    required this.engine,
    required this.picker,
    required this.saver,
    this.cacheDirOverride,
  });

  final OnnxEngine engine;
  final PhotoPicker picker;
  final MediaSaver saver;
  final Directory? cacheDirOverride;

  UiStage stage = UiStage.home;
  SelectedImage? image;
  UpscaleMode mode = UpscaleMode.x4;
  UpscalePlan? plan;
  UpscaleResult? result;
  UpscaleProgress progress = const UpscaleProgress(done: 0, total: 0);
  String? errorMessage;
  String? message;
  bool busy = false;

  bool _cancelRequested = false;
  int _noticeId = 0;

  /// Bump to invalidate stale asynchronous completions after a supersede.
  int _session = 0;

  int get noticeId => _noticeId;

  // ---------------------------------------------------------------- picking
  Future<void> pickPhoto() async {
    try {
      final img = await picker.pickPhoto();
      if (img == null) return; // user cancelled the picker
      _beginNewSession();
      _discardResult();
      image = img;
      plan = null;
      result = null;
      errorMessage = null;
      message = null;
      progress = const UpscaleProgress(done: 0, total: 0);
      stage = UiStage.selected;
      busy = false;
      _notify();
    } on PixLiftException catch (e) {
      _fail(e);
    } catch (e) {
      _fail(
        PixLiftException(
          PixLiftErrorKind.unknown,
          'That photo could not be opened.',
          '$e',
        ),
      );
    }
  }

  void setMode(UpscaleMode m) {
    if (stage != UiStage.selected) return;
    mode = m;
    plan = null;
    _notify();
  }

  /// Estimated output dimensions for the current image + mode (honest math).
  ({int width, int height}) get estimatedDims {
    final img = image;
    if (img == null) return (width: 0, height: 0);
    return TilePlanner.estimate(img.width, img.height, mode);
  }

  // --------------------------------------------------------------- upscaling
  Future<void> start() async {
    final img = image;
    if (img == null || busy) return; // no duplicates, no-busy reentry
    final session = _session;
    busy = true;
    _cancelRequested = false;
    final p = TilePlanner.plan(img.originalWidth, img.originalHeight, mode);
    plan = p;
    progress = UpscaleProgress(done: 0, total: p.tileCount);
    stage = UiStage.processing;
    errorMessage = null;
    _notify();

    try {
      final cacheDir = cacheDirOverride ?? await getCacheDir();
      final pipeline = UpscalePipeline(engine: engine, cacheDir: cacheDir);
      final res = await pipeline.process(
        img,
        mode,
        onProgress: (done, total) {
          if (session != _session || _cancelRequested) return;
          progress = UpscaleProgress(done: done, total: total);
          _notify();
        },
        isCancelled: () => _cancelRequested || session != _session,
      );
      if (session != _session || _cancelRequested) return; // superseded
      result = res;
      busy = false;
      stage = UiStage.result;
      _notify();
    } on UpscaleCancelledException {
      if (session == _session) {
        busy = false;
        stage = UiStage.selected;
        _notify();
      }
    } catch (e) {
      if (session != _session) return;
      busy = false;
      final err = e is PixLiftException
          ? e
          : PixLiftException(
              PixLiftErrorKind.unknown,
              'Something went wrong while lifting those pixels.',
              '$e',
            );
      errorMessage = err.message;
      stage = UiStage.selected;
      _notify();
    }
  }

  void cancelProcessing() {
    if (stage == UiStage.processing) {
      _cancelRequested = true;
    }
  }

  // ----------------------------------------------------------------- saving
  Future<void> saveToGallery() async {
    final r = result;
    if (r == null) return;
    try {
      await saver.saveToGallery(
        srcPath: r.outputPath,
        displayName: r.fileName,
        mime: r.format == 'png' ? 'image/png' : 'image/jpeg',
      );
      _showMessage('Saved to your gallery.');
    } on PixLiftException catch (e) {
      _fail(e);
    }
  }

  Future<void> share() async {
    final r = result;
    if (r == null) return;
    try {
      await saver.shareFile(r.outputPath, subject: 'Upscaled with PixLift');
    } on PixLiftException catch (e) {
      _fail(e);
    }
  }

  // ---------------------------------------------------------------- reset
  void pickAnother() {
    _beginNewSession();
    _discardResult();
    image = null;
    plan = null;
    result = null;
    errorMessage = null;
    message = null;
    busy = false;
    stage = UiStage.home;
    _notify();
  }

  void _beginNewSession() {
    _session++;
    _cancelRequested = false;
  }

  void _discardResult() {
    final old = result;
    if (old == null) return;
    final paths = <String>{old.outputPath, old.previewPath};
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Cache cleanup is best effort and must not interrupt the user flow.
      }
    }
  }

  void _showMessage(String text) {
    message = text;
    _noticeId++;
    _notify();
  }

  void _fail(PixLiftException e) {
    if (e.isCancellation) return;
    errorMessage = e.message;
    _noticeId++;
    if (stage == UiStage.processing) {
      busy = false;
      stage = UiStage.selected;
    }
    _notify();
  }

  void _notify() => notifyListeners();
}
