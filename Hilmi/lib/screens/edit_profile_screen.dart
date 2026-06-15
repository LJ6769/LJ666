// 编辑资料页：头像、昵称、简介保存。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/edit_profile_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/signup_assets.dart';
import 'package:hilmi/widgets/auth/signup_avatar_preview.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/profile/profile_edit_assets.dart';

/// 编辑资料（头像 / 昵称 / 简介）。
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetxScreen<EditProfileController>(
      create: EditProfileController.new,
      builder: (c) => Obx(() {
        final s = c.scale(context);
        final media = MediaQuery.of(context);
        final topInset = media.viewPadding.top;
        final bottomSafe = media.viewPadding.bottom;
        final keyboardHeight = media.viewInsets.bottom;
        final saveBarHeight = 56 * s + 16 * s + bottomSafe;
        final scrollBottomPad = keyboardHeight > 0
            ? keyboardHeight + 24 * s
            : saveBarHeight + 16 * s;
        final loading = c.loading.value;
        final saving = c.saving.value;
        final profile = c.profile.value;
        final avatarLocalPath = c.avatarLocalPath.value;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: splashBackground,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: splashBackground,
            resizeToAvoidBottomInset: false,
            body: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD14D4D),
                      strokeWidth: 2,
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          controller: c.scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            20 * s,
                            topInset + 56 * s,
                            20 * s,
                            scrollBottomPad,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionLabel(
                                scale: s,
                                asset: ProfileEditAssets.labelAvatar,
                              ),
                              SizedBox(height: 12 * s),
                              Center(
                                child: _buildAvatar(
                                  c,
                                  s,
                                  profile,
                                  avatarLocalPath,
                                  () => c.pickAvatar(context),
                                ),
                              ),
                              SizedBox(height: 24 * s),
                              _SectionLabel(
                                scale: s,
                                asset: ProfileEditAssets.labelName,
                              ),
                              SizedBox(height: 10 * s),
                              _OutlinedField(
                                scale: s,
                                height: 52 * s,
                                child: TextField(
                                  controller: c.nameController,
                                  onTapOutside: (_) =>
                                      dismissKeyboard(context),
                                  style: c.fieldTextStyle(s),
                                  decoration: c.fieldDecoration(s),
                                ),
                              ),
                              SizedBox(height: 22 * s),
                              _SectionLabel(
                                scale: s,
                                asset: ProfileEditAssets.labelIntro,
                              ),
                              SizedBox(height: 10 * s),
                              _IntroField(
                                scale: s,
                                controller: c.introController,
                                focusNode: c.introFocus,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: topInset + 8 * s,
                        child: Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18 * s,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      AuthTopBarButton(
                        top: topInset + 4 * s,
                        left: 16 * s,
                        size: 40 * s,
                        asset: ProfileEditAssets.btnBack,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      Positioned(
                        left: 20 * s,
                        right: 20 * s,
                        bottom: 16 * s + bottomSafe,
                        child: _SaveButton(
                          scale: s,
                          saving: saving,
                          onTap: () => c.onSave(context),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildAvatar(
    EditProfileController c,
    double s,
    UserProfile? profile,
    String? avatarLocalPath,
    VoidCallback onPickAvatar,
  ) {
    final size = 132 * s;
    final radius = 22 * s;
    final cameraSize = 44 * s;

    Widget avatarChild;
    if (avatarLocalPath != null) {
      avatarChild = SignupAvatarPreview(
        filePath: avatarLocalPath,
        size: size,
        borderRadius: radius,
        placeholder: _AvatarPlaceholder(size: size * 0.88),
      );
    } else if (profile != null && profile.hasAvatar) {
      avatarChild = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedMediaImage(
          url: profile.avatarUrl!,
          cacheKey: profile.avatarPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _AvatarPlaceholder(size: size * 0.88),
        ),
      );
    } else {
      avatarChild = _AvatarPlaceholder(size: size * 0.88);
    }

    return GestureDetector(
      onTap: onPickAvatar,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: Center(child: avatarChild)),
            Positioned(
              right: 0,
              bottom: 0,
              child: Image.asset(
                ProfileEditAssets.btnCamera,
                width: cameraSize,
                height: cameraSize,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.scale,
    required this.saving,
    required this.onTap,
  });

  final double scale;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return GestureDetector(
      onTap: saving ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: saving ? 0.65 : 1,
        child: SizedBox(
          height: 56 * s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  ProfileEditAssets.btnSave,
                  fit: BoxFit.fill,
                ),
              ),
              if (saving)
                SizedBox(
                  width: 22 * s,
                  height: 22 * s,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17 * s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.scale, required this.asset});

  final double scale;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        asset,
        height: 22 * scale,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Intro 多行输入框（1005×306 切图，按宽度等比缩放）。
class _IntroField extends StatelessWidget {
  const _IntroField({
    required this.scale,
    required this.controller,
    required this.focusNode,
  });

  final double scale;
  final TextEditingController controller;
  final FocusNode focusNode;

  static const _bgAspect = 1005 / 306;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / _bgAspect;

        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                ProfileEditAssets.fieldIntroBg,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 12 * s),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onTapOutside: (_) => dismissKeyboard(context),
                  keyboardType: TextInputType.multiline,
                  maxLines: 5,
                  minLines: 4,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontSize: 15 * s,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Briefly introduce yourself...',
                    hintStyle: TextStyle(
                      fontSize: 15 * s,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.35),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OutlinedField extends StatelessWidget {
  const _OutlinedField({
    required this.scale,
    required this.height,
    required this.child,
    this.backgroundAsset = ProfileEditAssets.fieldBg,
  });

  final double scale;
  final double height;
  final Widget child;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            backgroundAsset,
            fit: BoxFit.fill,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 10 * scale),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        SignupAssets.avatarPlaceholder,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
