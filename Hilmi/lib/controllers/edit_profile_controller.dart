// 编辑资料页：头像、昵称、简介加载与保存。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/gallery_media_picker.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileController extends GetxController {
  static const designWidth = 375.0;

  final nameController = TextEditingController();
  final introController = TextEditingController();
  final introFocus = FocusNode();
  final scrollController = ScrollController();
  final _galleryPicker = GalleryMediaPicker();

  final profile = Rxn<UserProfile>();
  final avatarLocalPath = RxnString();
  final loading = true.obs;
  final saving = false.obs;

  double scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  @override
  void onInit() {
    super.onInit();
    introFocus.addListener(_onIntroFocusChange);
    unawaited(loadProfile());
  }

  @override
  void onClose() {
    introFocus.removeListener(_onIntroFocusChange);
    scrollController.dispose();
    nameController.dispose();
    introController.dispose();
    introFocus.dispose();
    super.onClose();
  }

  void _onIntroFocusChange() {
    if (!introFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> loadProfile() async {
    final loaded =
        await AuthService.loadCurrentProfile(forceRefresh: true);
    if (isClosed) return;
    profile.value = loaded;
    loading.value = false;
    nameController.text = loaded?.displayName ?? '';
    introController.text = loaded?.bio?.trim() ?? '';
  }

  Future<ImageSource?> chooseAvatarSource(BuildContext context) async {
    final s = scale(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: splashBackground,
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
                'Photo Library',
                style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(
                'Camera',
                style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> pickAvatar(BuildContext context) async {
    final source = await chooseAvatarSource(context);
    if (source == null || !context.mounted) return;

    final files = await _galleryPicker.pickImages(limit: 1, source: source);
    if (!context.mounted) return;
    if (files == null) {
      await showAuthNoticeDialog(
        context,
        message: source == ImageSource.camera
            ? 'Camera access is required.'
            : 'Photo library access is required.',
      );
      return;
    }
    if (files.isEmpty) return;

    avatarLocalPath.value = files.first.path;
  }

  Future<void> onSave(BuildContext context) async {
    if (saving.value) return;
    dismissKeyboard(context);

    final name = nameController.text.trim();
    if (name.isEmpty) {
      await showAuthNoticeDialog(context, message: 'Please enter Name');
      return;
    }

    saving.value = true;
    try {
      await AuthService.updateCurrentProfile(
        displayName: name,
        bio: introController.text.trim(),
        avatarLocalPath: avatarLocalPath.value,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (!isClosed) saving.value = false;
    }
  }

  TextStyle fieldTextStyle(double s) => TextStyle(
        fontSize: 15 * s,
        fontWeight: FontWeight.w600,
        color: Colors.black,
        height: 1.35,
      );

  InputDecoration fieldDecoration(double s, {String? hint}) =>
      InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 15 * s,
          fontWeight: FontWeight.w600,
          color: Colors.black.withValues(alpha: 0.35),
          height: 1.35,
        ),
      );
}
