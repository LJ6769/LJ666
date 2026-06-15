// 朋友圈首次左右滑动全屏引导遮罩。
import 'package:flutter/material.dart';
import 'package:hilmi/constants/circle_guide_assets.dart';
import 'package:hilmi/core/circle_guide_service.dart';

/// 朋友圈首次进入：左右滑动切换帖子的全屏遮罩引导。
class CircleFeedGuideOverlay extends StatelessWidget {
  const CircleFeedGuideOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  static const _designWidth = 375.0;
  static const _imageDesignWidth = 180.0;
  static const _scrimColor = Color(0x8C000000);

  Future<void> _onOkTap() async {
    await CircleGuideService.markCircleGuideCompleted();
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final padding = MediaQuery.paddingOf(context);
    final contentWidth = _imageDesignWidth * scale;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _scrimColor),
        Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              28 * scale,
              padding.top,
              28 * scale,
              padding.bottom,
            ),
            child: GestureDetector(
              onTap: _onOkTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                CircleGuideAssets.icSwipe,
                width: contentWidth,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
