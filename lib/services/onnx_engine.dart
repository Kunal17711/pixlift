import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/pixlift_error.dart';

/// Result of one tiled inference call.
class TileRunResult {
  const TileRunResult({required this.outH, required this.outW});
  final int outH;
  final int outW;
}

/// Thin client over the native ONNX Runtime bridge.
///
/// The actual inference happens on a native background thread — the Dart side
/// only awaits the platform channel, so the UI isolate never blocks.
class OnnxEngine {
  OnnxEngine();

  static const MethodChannel _channel = MethodChannel(
    'com.bykunalbuilds.pixlift/onnx',
  );

  bool _ready = false;
  Completer<void>? _initCompleter;
  Object? _initError;

  bool get ready => _ready;

  /// Single-flight init: loads (or waits for) the ONNX session exactly once.
  Future<void> ensureInitialized() async {
    if (_ready) return;
    final existing = _initCompleter;
    if (existing != null) {
      await existing.future;
      if (_initError != null) throw _initError!;
      return;
    }
    final completer = Completer<void>();
    _initCompleter = completer;
    try {
      await _warmup();
      _ready = true;
      completer.complete();
    } catch (e) {
      // Allow a later retry (e.g. warm-up race) by resetting single-flight state.
      _initCompleter = null;
      _initError = null;
      completer.completeError(e);
      rethrow;
    }
  }

  Future<void> _warmup() async {
    final cacheDir = await _cacheDir();
    final modelFile = File('${cacheDir.path}/pixlift_model.onnx');
    // Materialize the bundled model once (asset -> cache file). Validate the
    // cached bytes so an interrupted write cannot permanently break startup.
    if (!modelFile.existsSync() || !await _hasExpectedDigest(modelFile)) {
      final data = await rootBundle.load(PixLiftConfig.modelAssetKey);
      await modelFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    if (!await _hasExpectedDigest(modelFile)) {
      throw PixLiftException(
        PixLiftErrorKind.modelLoadFailed,
        'The AI model could not be prepared on this device.',
        'model checksum mismatch',
      );
    }
    try {
      await _channel.invokeMethod<void>('init', {'modelPath': modelFile.path});
    } on PlatformException catch (e) {
      throw PixLiftException(
        PixLiftErrorKind.modelLoadFailed,
        'The AI model could not be loaded on this device.',
        e.message,
      );
    }
  }

  /// Runs 4x inference for one tile; the native side writes the planar RGB
  /// output to [outPath] and returns the output dimensions.
  Future<TileRunResult> upscaleTile(
    Uint8List inputChw,
    int h,
    int w,
    int scale,
    String outPath,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'upscaleTile',
        {'input': inputChw, 'h': h, 'w': w, 'scale': scale, 'outPath': outPath},
      );
      return TileRunResult(
        outH: (result?['outH'] as num?)?.toInt() ?? h * scale,
        outW: (result?['outW'] as num?)?.toInt() ?? w * scale,
      );
    } on PlatformException catch (e) {
      throw PixLiftException(
        e.code == 'LOW_MEMORY'
            ? PixLiftErrorKind.lowMemory
            : PixLiftErrorKind.inferenceFailed,
        e.code == 'LOW_MEMORY'
            ? 'This photo is too large for the available memory. Try 2× mode.'
            : 'Something went wrong while lifting these pixels.',
        e.message,
      );
    }
  }

  /// Encodes planar RGB bytes (file) into PNG/JPEG on the native side.
  Future<void> encodeImage({
    required String rawPath,
    required int w,
    required int h,
    required String format,
    required int quality,
    required String outPath,
  }) async {
    try {
      await _channel.invokeMethod<void>('encodeImage', {
        'rawPath': rawPath,
        'w': w,
        'h': h,
        'format': format,
        'quality': quality,
        'outPath': outPath,
      });
    } on PlatformException catch (e) {
      throw PixLiftException(
        e.code == 'LOW_MEMORY'
            ? PixLiftErrorKind.lowMemory
            : PixLiftErrorKind.unknown,
        e.code == 'LOW_MEMORY'
            ? 'This result is too large for the available memory. Try 2× mode.'
            : 'Could not finish saving the image.',
        e.message,
      );
    }
  }

  Future<void> dispose() async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // Best effort — the process owns the session.
    }
    _ready = false;
  }

  static Future<Directory> _cacheDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/pixlift');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<bool> _hasExpectedDigest(File file) async {
    if (!file.existsSync()) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == PixLiftConfig.modelSha256;
  }
}
