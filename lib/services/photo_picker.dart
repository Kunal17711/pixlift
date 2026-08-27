import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../features/upscaler/data/image_decoder.dart';
import '../features/upscaler/domain/upscale_types.dart';

/// Modern Android Photo Picker wrapper (no storage permissions required).
class PhotoPicker {
  PhotoPicker();

  final ImagePicker _picker = ImagePicker();

  /// Returns null when the user cancels.
  Future<SelectedImage?> pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
      maxWidth: null,
      maxHeight: null,
      imageQuality: null,
    );
    if (file == null) return null;
    final f = File(file.path);
    return ImageDecoder.decodeFile(f, file.name);
  }
}
