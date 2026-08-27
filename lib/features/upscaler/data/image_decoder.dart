import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../core/constants.dart';
import '../../../core/pixlift_error.dart';
import '../domain/upscale_types.dart';

/// Decodes a picked image file into a bounded RGBA buffer.
///
/// - EXIF orientation is applied automatically by the Flutter image codec.
/// - The decode is down-scaled to [PixLiftConfig.maxDecodeDim] so huge photos
///   never cause a memory spike (the AI model only ingests ~1/16th of that).
class ImageDecoder {
  ImageDecoder._();

  static Future<SelectedImage> decodeFile(File file, String name) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw PixLiftException(
        PixLiftErrorKind.corruptedImage,
        'That photo could not be read.',
      );
    }
    if (!_looksLikeImage(bytes)) {
      throw PixLiftException(
        PixLiftErrorKind.unsupportedImage,
        'That file is not a supported photo.',
      );
    }
    final decoded = await _decodeToRgba(bytes);
    return SelectedImage(
      path: file.path,
      name: name,
      width: decoded.width,
      height: decoded.height,
      rgba: decoded.rgba,
      originalWidth: decoded.originalWidth,
      originalHeight: decoded.originalHeight,
    );
  }

  static Future<_Decoded> _decodeToRgba(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final originalWidth = descriptor.width;
      final originalHeight = descriptor.height;
      var scale = 1.0;
      scale = math.min(scale, PixLiftConfig.maxDecodeDim / originalWidth);
      scale = math.min(scale, PixLiftConfig.maxDecodeDim / originalHeight);
      scale = math.min(
        scale,
        math.sqrt(
          PixLiftConfig.maxDecodePixels / (originalWidth * originalHeight),
        ),
      );
      final targetWidth = math.max(1, (originalWidth * scale).round());
      final targetHeight = math.max(1, (originalHeight * scale).round());
      codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final decodedWidth = image.width;
      final decodedHeight = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw PixLiftException(
          PixLiftErrorKind.corruptedImage,
          'That photo could not be decoded.',
        );
      }
      return _Decoded(
        width: decodedWidth,
        height: decodedHeight,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } on PixLiftException {
      rethrow;
    } catch (e) {
      throw PixLiftException(
        PixLiftErrorKind.corruptedImage,
        'That photo could not be decoded.',
        '$e',
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static bool _looksLikeImage(Uint8List b) {
    if (b.length < 12) return false;
    // JPEG
    if (b[0] == 0xFF && b[1] == 0xD8) return true;
    // PNG
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true;
    }
    // WebP: RIFF....WEBP
    if (b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return true;
    }
    // GIF
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true;
    // BMP
    if (b[0] == 0x42 && b[1] == 0x4D) return true;
    // HEIF/HEIC (brand 'ftyp' box)
    if (b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      return true;
    }
    return false;
  }
}

class _Decoded {
  const _Decoded({
    required this.width,
    required this.height,
    required this.originalWidth,
    required this.originalHeight,
    required this.rgba,
  });
  final int width;
  final int height;
  final int originalWidth;
  final int originalHeight;
  final Uint8List rgba;
}
