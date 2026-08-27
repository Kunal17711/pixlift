import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../core/pixlift_error.dart';

/// Saves and shares the final image. Saving uses the native Android media
/// store (no permissions on modern Android). Sharing uses the system share
/// sheet.
class MediaSaver {
  MediaSaver();

  Future<void> saveToGallery({
    required String srcPath,
    required String displayName,
    required String mime,
  }) async {
    try {
      await Gal.putImage(srcPath, album: 'PixLift');
    } catch (e) {
      throw PixLiftException(
        PixLiftErrorKind.saveFailed,
        'Could not save to your gallery. Check that you have enough free space.',
        '$e',
      );
    }
  }

  Future<void> shareFile(String path, {String? subject}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(path)], subject: subject),
      );
    } catch (e) {
      throw PixLiftException(
        PixLiftErrorKind.shareFailed,
        'Could not open the share sheet.',
        '$e',
      );
    }
  }
}
