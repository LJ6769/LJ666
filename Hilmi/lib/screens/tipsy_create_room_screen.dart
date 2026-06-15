// 创建 Tipsy Bar 聊天室：封面、标题、简介。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/tipsy_create_room_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/home_feed_cards.dart';
import 'package:hilmi/widgets/home_widgets.dart';
import 'package:hilmi/widgets/tipsy/tipsy_assets.dart';
import 'package:image_picker/image_picker.dart';

/// Tipsy Bar 创建聊天室（对齐设计稿）。
class TipsyCreateRoomScreen extends StatelessWidget {
  const TipsyCreateRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetxScreen<TipsyCreateRoomController>(
      create: TipsyCreateRoomController.new,
      builder: (c) => Obx(() {
        final s = c.scale(context);
        final bottomPad = MediaQuery.paddingOf(context).bottom;
        final coverWidth = HomeTipsyBarCard.coverPhotoWidth * s;
        final coverHeight = HomeTipsyBarCard.coverPhotoHeight * s;
        final coverRadius = HomeTipsyBarCard.coverPhotoRadius * s;
        final submitting = c.submitting.value;
        final coverImage = c.coverImage.value;
        final _ = c.formRevision.value;

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
                        padding:
                            EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 16 * s),
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
                            _TitleField(scale: s, controller: c.titleController),
                            SizedBox(height: 20 * s),
                            Image.asset(
                              TipsyAssets.createLabelIntro,
                              height: 22 * s,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                            ),
                            SizedBox(height: 10 * s),
                            _IntroField(scale: s, controller: c.introController),
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
                              child: coverImage == null
                                  ? _EmptyCoverSlot(
                                      width: coverWidth,
                                      height: coverHeight,
                                      onTap: () => c.pickCover(context),
                                    )
                                  : _FilledCoverSlot(
                                      scale: s,
                                      width: coverWidth,
                                      height: coverHeight,
                                      radius: coverRadius,
                                      file: coverImage,
                                      onRemove: c.removeCover,
                                      onRetap: () => c.pickCover(context),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20 * s,
                        0,
                        20 * s,
                        bottomPad + 12 * s,
                      ),
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
                                '${TipsyCreateRoomController.createCost}',
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
                            submitting: submitting,
                            isReady: c.isReady,
                            onTap: () => c.onCreate(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (submitting)
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
      }),
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
