import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/services/tipsy_bar_room_creator.dart';
import 'package:hilmi/utils/gallery_media_picker.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/utils/open_coins_store.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/home_feed_cards.dart';
import 'package:hilmi/widgets/home_widgets.dart';
import 'package:hilmi/widgets/tipsy/tipsy_assets.dart';
import 'package:hilmi/widgets/tipsy/tipsy_bar_room_create_success_dialog.dart';
import 'package:image_picker/image_picker.dart';

/// Tipsy Bar 创建聊天室（对齐设计稿）。
class TipsyCreateRoomScreen extends StatefulWidget {
  const TipsyCreateRoomScreen({super.key});

  static const _designWidth = 375.0;
  static const _createCost = TipsyBarRoomCreator.createCost;

  @override
  State<TipsyCreateRoomScreen> createState() => _TipsyCreateRoomScreenState();
}

class _TipsyCreateRoomScreenState extends State<TipsyCreateRoomScreen> {
  final _titleController = TextEditingController();
  final _introController = TextEditingController();
  final _galleryPicker = GalleryMediaPicker();
  XFile? _coverImage;
  bool _submitting = false;

  double _scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / TipsyCreateRoomScreen._designWidth;

  @override
  void initState() {
    super.initState();
    void refreshForm() {
      if (mounted) setState(() {});
    }
    _titleController.addListener(refreshForm);
    _introController.addListener(refreshForm);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<ImageSource?> _chooseCoverSource() {
    final s = _scale(context);

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

  Future<void> _pickCover() async {
    final source = await _chooseCoverSource();
    if (source == null || !mounted) return;

    try {
      final files = await _galleryPicker.pickImages(limit: 1, source: source);
      if (!mounted) return;
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
      setState(() => _coverImage = files.first);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not choose cover: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onCreate() async {
    if (_submitting) return;

    final title = _titleController.text.trim();
    final intro = _introController.text.trim();
    if (title.isEmpty) {
      _showSnack('Please enter a title');
      return;
    }
    if (intro.isEmpty) {
      _showSnack('Please enter an intro');
      return;
    }
    if (_coverImage == null) {
      _showSnack('Please upload a cover');
      return;
    }

    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to create a chat room')) {
      return;
    }
    if (!mounted) return;

    final coins = AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;
    if (coins < TipsyCreateRoomScreen._createCost) {
      _showSnack('Not enough coins. ${TipsyCreateRoomScreen._createCost} coins required');
      await openCoinsStore(context);
      if (mounted) {
        await AuthService.loadCurrentProfile(forceRefresh: true);
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await TipsyBarRoomCreator.create(
        title: title,
        description: intro,
        coverImage: _coverImage!,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await TipsyBarRoomCreateSuccessDialog.show(context);
      if (!mounted) return;
      Navigator.of(context).pop(result.room);
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'Could not create room: $error';
      _showSnack(message);
    } finally {
      if (mounted && _submitting) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final coverWidth = HomeTipsyBarCard.coverPhotoWidth * s;
    final coverHeight = HomeTipsyBarCard.coverPhotoHeight * s;
    final coverRadius = HomeTipsyBarCard.coverPhotoRadius * s;

    return Scaffold(
      backgroundColor: splashBackground,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 16 * s, 8 * s),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Image.asset(
                          TipsyAssets.createBtnBack,
                          width: 44 * s,
                          height: 44 * s,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Create Room',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20 * s,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(width: 44 * s),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    clipBehavior: Clip.none,
                    padding: EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 16 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          TipsyAssets.createLabelTitle,
                          height: 22 * s,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                        SizedBox(height: 10 * s),
                        _TitleField(scale: s, controller: _titleController),
                        SizedBox(height: 20 * s),
                        Image.asset(
                          TipsyAssets.createLabelIntro,
                          height: 22 * s,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                        SizedBox(height: 10 * s),
                        _IntroField(scale: s, controller: _introController),
                        SizedBox(height: 20 * s),
                        Image.asset(
                          TipsyAssets.createLabelCover,
                          height: 22 * s,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                        SizedBox(height: 12 * s),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _coverImage == null
                              ? _EmptyCoverSlot(
                                  width: coverWidth,
                                  height: coverHeight,
                                  onTap: _pickCover,
                                )
                              : _FilledCoverSlot(
                                  scale: s,
                                  width: coverWidth,
                                  height: coverHeight,
                                  radius: coverRadius,
                                  file: _coverImage!,
                                  onRemove: () =>
                                      setState(() => _coverImage = null),
                                  onRetap: _pickCover,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(20 * s, 0, 20 * s, bottomPad + 12 * s),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            TipsyAssets.createIcCoin,
                            width: 20 * s,
                            height: 20 * s,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: 6 * s),
                          Text(
                            '${TipsyCreateRoomScreen._createCost}',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16 * s,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10 * s),
                      _CreateButton(
                        scale: s,
                        submitting: _submitting,
                        isReady: _titleController.text.trim().isNotEmpty &&
                            _introController.text.trim().isNotEmpty &&
                            _coverImage != null,
                        onTap: _onCreate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD14D4D),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.scale,
    required this.controller,
  });

  final double scale;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final radius = BorderRadius.circular(14 * s);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
        child: TextField(
          controller: controller,
          onTapOutside: (_) => dismissKeyboard(context),
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: 14 * s,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: 'Please enter...',
            hintStyle: TextStyle(color: Color(0xFFB0B0B0)),
          ),
        ),
      ),
    );
  }
}

class _IntroField extends StatelessWidget {
  const _IntroField({
    required this.scale,
    required this.controller,
  });

  final double scale;
  final TextEditingController controller;

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
            children: [
              Image.asset(
                TipsyAssets.createFieldIntroBg,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 12 * s),
                  child: TextField(
                    controller: controller,
                    onTapOutside: (_) => dismissKeyboard(context),
                    maxLines: 5,
                    minLines: 4,
                    style: TextStyle(
                      color: const Color(0xFF616161),
                      fontSize: 14 * s,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Please enter...',
                      hintStyle: TextStyle(color: Color(0xFFB0B0B0)),
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

class _EmptyCoverSlot extends StatelessWidget {
  const _EmptyCoverSlot({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        TipsyAssets.createCoverSlotEmpty,
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _FilledCoverSlot extends StatelessWidget {
  const _FilledCoverSlot({
    required this.scale,
    required this.width,
    required this.height,
    required this.radius,
    required this.file,
    required this.onRemove,
    required this.onRetap,
  });

  final double scale;
  final double width;
  final double height;
  final double radius;
  final XFile file;
  final VoidCallback onRemove;
  final VoidCallback onRetap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final outerRadius = BorderRadius.circular(radius);
    final innerRadius = BorderRadius.circular(
      (radius - homeBorderWidth).clamp(0.0, radius),
    );
    final removeSize = 28 * s;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onRetap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: outerRadius,
                border: Border.all(
                  color: Colors.black,
                  width: homeBorderWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: innerRadius,
                child: Image.file(
                  File(file.path),
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            top: -6 * s,
            right: -6 * s,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                TipsyAssets.createBtnRemoveCover,
                width: removeSize,
                height: removeSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.scale,
    required this.submitting,
    required this.isReady,
    required this.onTap,
  });

  final double scale;
  final bool submitting;
  final bool isReady;
  final VoidCallback onTap;

  static const _bgAspect = 1005 / 153;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final width = MediaQuery.sizeOf(context).width - 40 * s;
    final height = width / _bgAspect;
    final asset = isReady
        ? TipsyAssets.createBtnCreateActive
        : TipsyAssets.createBtnCreateInactive;

    return GestureDetector(
      onTap: submitting ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: submitting ? 0.65 : 1,
        child: Image.asset(
          asset,
          width: width,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
