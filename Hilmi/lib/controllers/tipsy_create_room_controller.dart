// Tipsy Bar 创建聊天室：表单状态与提交逻辑。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/services/tipsy_bar_room_creator.dart';
import 'package:hilmi/utils/gallery_media_picker.dart';
import 'package:hilmi/utils/open_coins_store.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/tipsy/tipsy_bar_room_create_success_dialog.dart';
import 'package:image_picker/image_picker.dart';

class TipsyCreateRoomController extends GetxController {
  static const designWidth = 375.0;
  static const createCost = TipsyBarRoomCreator.createCost;

  final titleController = TextEditingController();
  final introController = TextEditingController();
  final _galleryPicker = GalleryMediaPicker();

  final coverImage = Rxn<XFile>();
  final submitting = false.obs;
  final formRevision = 0.obs;

  double scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  bool get isReady =>
      titleController.text.trim().isNotEmpty &&
      introController.text.trim().isNotEmpty &&
      coverImage.value != null;

  @override
  void onInit() {
    super.onInit();
    void refreshForm() => formRevision.value++;
    titleController.addListener(refreshForm);
    introController.addListener(refreshForm);
  }

  @override
  void onClose() {
    titleController.dispose();
    introController.dispose();
    super.onClose();
  }

  Future<ImageSource?> chooseCoverSource(BuildContext context) {
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
                style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(
                'Take Photo',
                style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            SizedBox(height: 8 * s),
          ],
        ),
      ),
    );
  }

  Future<void> pickCover(BuildContext context) async {
    final source = await chooseCoverSource(context);
    if (source == null || !context.mounted) return;

    try {
      final files = await _galleryPicker.pickImages(limit: 1, source: source);
      if (!context.mounted) return;
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
      coverImage.value = files.first;
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not choose cover: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void removeCover() {
    coverImage.value = null;
  }

  Future<void> onCreate(BuildContext context) async {
    if (submitting.value) return;

    final title = titleController.text.trim();
    final intro = introController.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'Please enter a title');
      return;
    }
    if (intro.isEmpty) {
      showSnack(context, 'Please enter an intro');
      return;
    }
    final cover = coverImage.value;
    if (cover == null) {
      showSnack(context, 'Please upload a cover');
      return;
    }

    if (!await ensureLoggedIn(
      context,
      loginHint: 'Please sign in to create a chat room',
    )) {
      return;
    }
    if (!context.mounted) return;

    final coins = AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;
    if (coins < createCost) {
      showSnack(
        context,
        'Not enough coins. $createCost coins required',
      );
      await openCoinsStore(context);
      if (context.mounted) {
        await AuthService.loadCurrentProfile(forceRefresh: true);
      }
      return;
    }

    submitting.value = true;
    try {
      final result = await TipsyBarRoomCreator.create(
        title: title,
        description: intro,
        coverImage: cover,
      );
      if (!context.mounted) return;
      submitting.value = false;
      await TipsyBarRoomCreateSuccessDialog.show(context);
      if (!context.mounted) return;
      Navigator.of(context).pop(result.room);
    } catch (error) {
      if (!context.mounted) return;
      final message = error is StateError
          ? error.message
          : 'Could not create room: $error';
      showSnack(context, message);
    } finally {
      if (!isClosed && submitting.value) submitting.value = false;
    }
  }

  void showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
