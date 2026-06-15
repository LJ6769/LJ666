// 朋友圈发帖页：图片/视频 + 文案 + 发布。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/circle_edit_post_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// 朋友圈发帖页（对齐设计稿：图片最多 6 张 + Intro + Save）。
class CircleEditPostScreen extends StatelessWidget {
  const CircleEditPostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetxScreen<CircleEditPostController>(
      create: () => CircleEditPostController(),
      builder: (c) => _CircleEditPostBody(controller: c),
    );
  }
}

class _CircleEditPostBody extends StatelessWidget {
  const _CircleEditPostBody({required this.controller});

  final CircleEditPostController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.scale(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: splashBackground,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(scale: s, onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20 * s, 28 * s, 20 * s, 16 * s),
                    child: Obx(
                      () {
                        final mediaType = controller.mediaType.value;
                        final isImage =
                            mediaType == CircleEditPostMediaType.image;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MediaTypeTabs(
                              scale: s,
                              mediaType: mediaType,
                              onImageTap: () => controller.setMediaType(
                                CircleEditPostMediaType.image,
                              ),
                              onVideoTap: () => controller.setMediaType(
                                CircleEditPostMediaType.video,
                              ),
                            ),
                            SizedBox(height: 22 * s),
                            if (isImage) ...[
                              Image.asset(
                                CircleAssets.editLabelImage,
                                height: 22 * s,
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                              ),
                              SizedBox(height: 12 * s),
                              _ImageGrid(
                                scale: s,
                                images: controller.pickedImages.toList(),
                                onAddTap: () =>
                                    controller.pickImages(context),
                                onRemove: controller.removeImage,
                              ),
                            ] else ...[
                              Image.asset(
                                CircleAssets.editLabelVideo,
                                height: 22 * s,
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                              ),
                              SizedBox(height: 12 * s),
                              _VideoUploadSection(
                                scale: s,
                                video: controller.pickedVideo.value,
                                onAddTap: () => controller.pickVideo(context),
                                onRemove: controller.removeVideo,
                              ),
                            ],
                            SizedBox(height: 12 * s),
                            Image.asset(
                              CircleAssets.editLabelIntro,
                              height: 22 * s,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                            ),
                            SizedBox(height: 10 * s),
                            _IntroField(
                              scale: s,
                              controller: controller.introController,
                            ),
                          ],
                        );
                      },
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
                  child: Obx(
                    () => _SaveButton(
                      scale: s,
                      saving: controller.saving.value,
                      onTap: () => controller.onSave(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => controller.saving.value
                ? Positioned.fill(
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
                  )
                : const SizedBox.shrink(),
          ),
        ],
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

  static const _bgAspect = 1005 / 153;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final width = MediaQuery.sizeOf(context).width - 40 * s;
    final height = width / _bgAspect;

    return GestureDetector(
      onTap: saving ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: saving ? 0.65 : 1,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                CircleAssets.editBtnSave,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18 * s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.scale,
    required this.onBack,
  });

  final double scale;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return Padding(
      padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 16 * s, 12 * s),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              CircleAssets.editBtnBack,
              width: 44 * s,
              height: 44 * s,
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: Text(
              'Edit Post',
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
    );
  }
}

class _MediaTypeTabs extends StatelessWidget {
  const _MediaTypeTabs({
    required this.scale,
    required this.mediaType,
    required this.onImageTap,
    required this.onVideoTap,
  });

  final double scale;
  final CircleEditPostMediaType mediaType;
  final VoidCallback onImageTap;
  final VoidCallback onVideoTap;

  static const _tabAspect = 264 / 111;

  /// Image / Video 切图显示高度（原 36，等比放大至与其他页选项卡一致）。
  static const _tabHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final isImage = mediaType == CircleEditPostMediaType.image;
    final tabHeight = _tabHeight * s;
    final tabWidth = tabHeight * _tabAspect;

    return Row(
      children: [
        _MediaTabSlot(
          width: tabWidth,
          height: tabHeight,
          onTap: onImageTap,
          child: Image.asset(
            isImage
                ? CircleAssets.editTabImageActive
                : CircleAssets.editTabImageInactive,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: 10 * s),
        _MediaTabSlot(
          width: tabWidth,
          height: tabHeight,
          onTap: onVideoTap,
          child: Image.asset(
            isImage
                ? CircleAssets.editTabVideoInactive
                : CircleAssets.editTabVideoActive,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _MediaTabSlot extends StatelessWidget {
  const _MediaTabSlot({
    required this.width,
    required this.height,
    required this.onTap,
    required this.child,
  });

  final double width;
  final double height;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.scale,
    required this.images,
    required this.onAddTap,
    required this.onRemove,
  });

  final double scale;
  final List<XFile> images;
  final VoidCallback onAddTap;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final width = MediaQuery.sizeOf(context).width;
    final cellGap = 10 * s;
    final cellSize = (width - 40 * s - cellGap * 2) / 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: cellGap,
        crossAxisSpacing: cellGap,
        childAspectRatio: 1,
      ),
      itemCount: CircleEditPostController.maxImages,
      itemBuilder: (context, index) {
        if (index < images.length) {
          return _FilledImageSlot(
            scale: s,
            size: cellSize,
            file: images[index],
            onRemove: () => onRemove(index),
          );
        }
        return _EmptyImageSlot(
          scale: s,
          size: cellSize,
          onTap: onAddTap,
        );
      },
    );
  }
}

/// 图片空位：整张切图作为占位（含边框与图标）。
class _EmptyImageSlot extends StatelessWidget {
  const _EmptyImageSlot({
    required this.scale,
    required this.size,
    required this.onTap,
  });

  final double scale;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          CircleAssets.editImageSlotEmpty,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 视频空位：整张切图作为占位（含边框与图标）。
class _EmptyVideoSlot extends StatelessWidget {
  const _EmptyVideoSlot({
    required this.scale,
    required this.size,
    required this.onTap,
  });

  final double scale;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          CircleAssets.editVideoSlotEmpty,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _FilledImageSlot extends StatelessWidget {
  const _FilledImageSlot({
    required this.scale,
    required this.size,
    required this.file,
    required this.onRemove,
  });

  final double scale;
  final double size;
  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    final radius =
        BorderRadius.circular(CircleEditPostController.slotRadius * s);
    final innerRadius = BorderRadius.circular(
      (CircleEditPostController.slotRadius - 2) * s,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: ClipRRect(
                borderRadius: innerRadius,
                child: Image.file(
                  File(file.path),
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
                CircleAssets.editBtnRemoveImage,
                width: 28 * s,
                height: 28 * s,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final s = scale;

    final radius = BorderRadius.circular(16 * s);
    final innerRadius = BorderRadius.circular(14 * s);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: ClipRRect(
        borderRadius: innerRadius,
        child: Stack(
          children: [
            Image.asset(
              CircleAssets.editIntroFieldBg,
              fit: BoxFit.fitWidth,
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
                    hintText: 'Write something about your post…',
                    hintStyle: TextStyle(color: Color(0xFFB0B0B0)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoUploadSection extends StatelessWidget {
  const _VideoUploadSection({
    required this.scale,
    required this.video,
    required this.onAddTap,
    required this.onRemove,
  });

  final double scale;
  final XFile? video;
  final VoidCallback onAddTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final width = MediaQuery.sizeOf(context).width;
    final cellGap = 10 * s;
    final cellSize = (width - 40 * s - cellGap * 2) / 3;

    return Align(
      alignment: Alignment.centerLeft,
      child: video == null
          ? _EmptyVideoSlot(
              scale: s,
              size: cellSize,
              onTap: onAddTap,
            )
          : _FilledVideoSlot(
              scale: s,
              size: cellSize,
              file: video!,
              onRemove: onRemove,
            ),
    );
  }
}

class _FilledVideoSlot extends StatefulWidget {
  const _FilledVideoSlot({
    required this.scale,
    required this.size,
    required this.file,
    required this.onRemove,
  });

  final double scale;
  final double size;
  final XFile file;
  final VoidCallback onRemove;

  @override
  State<_FilledVideoSlot> createState() => _FilledVideoSlotState();
}

class _FilledVideoSlotState extends State<_FilledVideoSlot> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _FilledVideoSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _disposeController();
      _initController();
    }
  }

  void _initController() {
    final controller = VideoPlayerController.file(File(widget.file.path));
    _controller = controller;
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final size = widget.size;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final radius =
        BorderRadius.circular(CircleEditPostController.slotRadius * s);
    final innerRadius = BorderRadius.circular(
      (CircleEditPostController.slotRadius - 2) * s,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: innerRadius,
                child: ready
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
              ),
            ),
          ),
          if (ready)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 36 * s,
                  ),
                ),
              ),
            ),
          Positioned(
            top: -6 * s,
            right: -6 * s,
            child: GestureDetector(
              onTap: widget.onRemove,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                CircleAssets.editBtnRemoveImage,
                width: 28 * s,
                height: 28 * s,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
