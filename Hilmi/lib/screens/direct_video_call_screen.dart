import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/message/video_call_assets.dart';
import 'package:hilmi/widgets/message/video_call_layout.dart';

/// 私信视频通话等待页（对齐设计稿；挂断结束并返回聊天）。
class DirectVideoCallScreen extends StatelessWidget {
  const DirectVideoCallScreen({super.key, required this.peer});

  final DirectChatPeer peer;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / VideoCallLayout.designWidth;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _RemoteVideoBackground(avatarUrl: peer.avatarUrl),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomGradientFade(
                width: MediaQuery.sizeOf(context).width,
              ),
            ),
            Positioned(
              left: VideoCallLayout.bottomPanelPadH * s,
              right: VideoCallLayout.bottomPanelPadH * s,
              bottom: bottom + 28 * s,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      VideoCallAssets.btnEndCall,
                      width: VideoCallLayout.endCallBtnW * s,
                      height: VideoCallLayout.endCallBtnH * s,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: VideoCallLayout.endCallToTextGap * s),
                  Text(
                    'Waiting for the call to be answered...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: VideoCallLayout.statusLineGap * s),
                  Text(
                    'Please be patient!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部渐变切图 + 纵向 alpha 遮罩：上方全透明，不挡背后画面。
class _BottomGradientFade extends StatelessWidget {
  const _BottomGradientFade({required this.width});

  final double width;

  /// bottom_gradient.jpg 原图宽高比 1024×548。
  static const _assetAspect = 548 / 1024;

  @override
  Widget build(BuildContext context) {
    final height = width * _assetAspect;

    return SizedBox(
      width: width,
      height: height,
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00000000),
            Color(0x33000000),
            Color(0xFFFFFFFF),
          ],
          stops: [0.0, 0.42, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          VideoCallAssets.bottomGradient,
          width: width,
          height: height,
          fit: BoxFit.fill,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _RemoteVideoBackground extends StatelessWidget {
  const _RemoteVideoBackground({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return CachedMediaImage(
        url: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const _VideoPlaceholder(),
      );
    }
    return const _VideoPlaceholder();
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2A2438),
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 120,
          color: Color(0x66FFFFFF),
        ),
      ),
    );
  }
}
