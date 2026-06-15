// 朋友圈发帖页：图片/视频 + 文案 + 发布状态。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/services/circle_post_publisher.dart';
import 'package:hilmi/utils/gallery_media_picker.dart';
import 'package:hilmi/widgets/circle/circle_post_publish_success_dialog.dart';
import 'package:image_picker/image_picker.dart';

enum CircleEditPostMediaType { image, video }

class CircleEditPostController extends GetxController {
  static const maxImages = 6;
  static const designWidth = 375.0;
  static const slotRadius = 14.0;

  final introController = TextEditingController();
  final galleryPicker = GalleryMediaPicker();
  final pickedImages = <XFile>[].obs;
  final pickedVideo = Rxn<XFile>();
  final mediaType = CircleEditPostMediaType.image.obs;
  final saving = false.obs;

  @override
  void onClose() {
    introController.dispose();
    super.onClose();
  }

  double scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  Future<ImageSource?> chooseImageSource(BuildContext context) {
    final s = scale(context);

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFFFDF9ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16 * s)),
        side: const BorderSide(color: Colors.black, width: 2),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                'Choose from Library',
                style: TextStyle(
                  fontSize: 16 * s,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(
                'Take Photo',
                style: TextStyle(
                  fontSize: 16 * s,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            SizedBox(height: 8 * s),
          ],
        ),
      ),
    );
  }

  Future<void> pickImages(BuildContext context) async {
    if (mediaType.value != CircleEditPostMediaType.image) return;
    final remaining = maxImages - pickedImages.length;
    if (remaining <= 0) return;

    final source = await chooseImageSource(context);
    if (source == null || isClosed) return;

    try {
      final files = await galleryPicker.pickImages(
        limit: remaining,
        source: source,
      );
      if (isClosed) return;
      if (files == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Allow camera access and try again'
                  : 'Allow photo library access and try again',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (files.isEmpty) return;
      pickedImages.addAll(files);
      if (pickedImages.length > maxImages) {
        pickedImages.removeRange(maxImages, pickedImages.length);
      }
    } catch (error) {
      if (isClosed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not choose image: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void removeImage(int index) {
    pickedImages.removeAt(index);
  }

  Future<void> pickVideo(BuildContext context) async {
    if (mediaType.value != CircleEditPostMediaType.video) return;

    try {
      if (!await galleryPicker.ensureGalleryAccess(forVideo: true)) {
        if (isClosed) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow photo library access and try again'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final file = await galleryPicker.pickVideo();
      if (isClosed) return;
      if (file == null) return;
      pickedVideo.value = file;
    } catch (error) {
      if (isClosed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not choose video: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void removeVideo() {
    pickedVideo.value = null;
  }

  Future<void> onSave(BuildContext context) async {
    if (saving.value) return;

    final intro = introController.text.trim();
    if (mediaType.value == CircleEditPostMediaType.video) {
      if (pickedVideo.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add a video'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else if (pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one image'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    saving.value = true;
    try {
      await CirclePostPublisher.publish(
        content: intro,
        images: mediaType.value == CircleEditPostMediaType.image
            ? pickedImages.toList()
            : const [],
        video: mediaType.value == CircleEditPostMediaType.video
            ? pickedVideo.value
            : null,
      );
      if (isClosed) return;
      saving.value = false;
      await CirclePostPublishSuccessDialog.show(context);
      if (isClosed) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (isClosed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publishErrorMessage(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!isClosed && saving.value) saving.value = false;
    }
  }

  String publishErrorMessage(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid post';
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Publish failed. Please try again.';
  }

  void setMediaType(CircleEditPostMediaType type) {
    mediaType.value = type;
  }
}
