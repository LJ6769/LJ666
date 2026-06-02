import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// 从相册 / 相机选择图片，从相册选择视频。
class GalleryMediaPicker {
  GalleryMediaPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<bool> ensureGalleryAccess({required bool forVideo}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      final permission = forVideo ? Permission.videos : Permission.photos;
      var status = await permission.status;
      if (status.isGranted || status.isLimited) return true;
      status = await permission.request();
      return status.isGranted || status.isLimited;
    }

    // iOS：多图选择走 PHPicker 可不申请权限；视频仍需相册权限。
    if (!forVideo) return true;

    var status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;
    status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> ensureCameraAccess() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 选图，最多 [limit] 张。
  /// [source] 为相机时每次仅一张；为相册时可多选。
  /// 返回 `null` 表示无权限；空列表表示用户取消。
  Future<List<XFile>?> pickImages({
    required int limit,
    required ImageSource source,
  }) async {
    if (limit <= 0) return const [];

    if (source == ImageSource.camera) {
      if (!await ensureCameraAccess()) return null;
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return file != null ? [file] : [];
    }

    if (!await ensureGalleryAccess(forVideo: false)) {
      return null;
    }

    if (limit == 1) {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return file != null ? [file] : [];
    }

    return _picker.pickMultiImage(
      imageQuality: 85,
      limit: limit,
    );
  }

  /// 从相册选一个视频（调用前请先 [ensureGalleryAccess]）。
  Future<XFile?> pickVideo() {
    return _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
  }
}
