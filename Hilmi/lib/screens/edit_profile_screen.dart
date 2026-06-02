import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/gallery_media_picker.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/signup_assets.dart';
import 'package:hilmi/widgets/auth/signup_avatar_preview.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/profile/profile_edit_assets.dart';
import 'package:image_picker/image_picker.dart';

/// 编辑资料（头像 / 昵称 / 简介）。
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static const _designWidth = 375.0;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _introController = TextEditingController();
  final _introFocus = FocusNode();
  final _scrollController = ScrollController();
  final _galleryPicker = GalleryMediaPicker();

  UserProfile? _profile;
  String? _avatarLocalPath;
  bool _loading = true;
  bool _saving = false;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / EditProfileScreen._designWidth;

  @override
  void initState() {
    super.initState();
    _introFocus.addListener(_onIntroFocusChange);
    _loadProfile();
  }

  @override
  void dispose() {
    _introFocus.removeListener(_onIntroFocusChange);
    _scrollController.dispose();
    _nameController.dispose();
    _introController.dispose();
    _introFocus.dispose();
    super.dispose();
  }

  void _onIntroFocusChange() {
    if (!_introFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadProfile() async {
    final profile =
        await AuthService.loadCurrentProfile(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
      _nameController.text = profile?.displayName ?? '';
      _introController.text = profile?.bio?.trim() ?? '';
    });
  }

  Future<ImageSource?> _chooseAvatarSource() async {
    final s = _s(context);
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

  Future<void> _pickAvatar() async {
    final source = await _chooseAvatarSource();
    if (source == null || !mounted) return;

    final files = await _galleryPicker.pickImages(limit: 1, source: source);
    if (!mounted) return;
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

    setState(() => _avatarLocalPath = files.first.path);
  }

  Future<void> _onSave() async {
    if (_saving) return;
    dismissKeyboard(context);

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await showAuthNoticeDialog(context, message: 'Please enter Name');
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthService.updateCurrentProfile(
        displayName: name,
        bio: _introController.text.trim(),
        avatarLocalPath: _avatarLocalPath,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final media = MediaQuery.of(context);
    // viewPadding 不随键盘变化；padding.bottom 键盘弹出时会变 0 导致 Save 位移。
    final topInset = media.viewPadding.top;
    final bottomSafe = media.viewPadding.bottom;
    final keyboardHeight = media.viewInsets.bottom;
    final saveBarHeight = 56 * s + 16 * s + bottomSafe;
    final scrollBottomPad = keyboardHeight > 0
        ? keyboardHeight + 24 * s
        : saveBarHeight + 16 * s;

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
        body: _loading
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
                      controller: _scrollController,
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
                          Center(child: _buildAvatar(s)),
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
                              controller: _nameController,
                              onTapOutside: (_) =>
                                  dismissKeyboard(context),
                              style: _fieldTextStyle(s),
                              decoration: _fieldDecoration(s),
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
                            controller: _introController,
                            focusNode: _introFocus,
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
                      saving: _saving,
                      onTap: _onSave,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  TextStyle _fieldTextStyle(double s) => TextStyle(
        fontSize: 15 * s,
        fontWeight: FontWeight.w600,
        color: Colors.black,
        height: 1.35,
      );

  InputDecoration _fieldDecoration(double s, {String? hint}) =>
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

  Widget _buildAvatar(double s) {
    final size = 132 * s;
    final radius = 22 * s;
    final cameraSize = 44 * s;
    final profile = _profile;

    Widget avatarChild;
    if (_avatarLocalPath != null) {
      avatarChild = SignupAvatarPreview(
        filePath: _avatarLocalPath!,
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
      onTap: _pickAvatar,
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
