// 直播间全屏页：视频、聊天、礼物、底部输入。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/live_room_controller.dart';
import 'package:hilmi/core/app_system_ui.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/data/live_chat_repository.dart';
import 'package:hilmi/data/live_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/live_room/live_gift_notification_banner.dart';
import 'package:hilmi/widgets/live_room/live_room_bottom_bar.dart';
import 'package:hilmi/widgets/live_room/live_room_chat_panel.dart';
import 'package:hilmi/widgets/live_room/live_room_top_bar.dart';
import 'package:hilmi/widgets/live_room/live_room_video_background.dart';

/// 直播间：全屏视频 + 可下滑聊天区 + 底部输入（布局对齐 Tjgo）。
class LiveRoomScreen extends StatelessWidget {
  const LiveRoomScreen({
    super.key,
    required this.preview,
    this.initialVideoUrl,
    this.liveRepository = const LiveRepository(),
    this.liveChatRepository = const LiveChatRepository(),
  });

  final LiveRoom preview;
  final String? initialVideoUrl;
  final LiveRepository liveRepository;
  final LiveChatRepository liveChatRepository;

  static const _designWidth = 375.0;
  static const _contentUpShift = 0.18;
  static const _videoAlignment = Alignment(0, -0.55);
  static const _chatOverlayTopFraction = 0.50;
  static const _giftBannerTopInsetDesign = 16.0;
  static const _inputBarHeight = 48.0;
  static const _chatGapAboveInput = 8.0;

  @override
  Widget build(BuildContext context) {
    return GetxScreen<LiveRoomController>(
      create: () => LiveRoomController(
        preview: preview,
        initialVideoUrl: initialVideoUrl,
        liveRepository: liveRepository,
        liveChatRepository: liveChatRepository,
      ),
      builder: (c) => _LiveRoomBody(controller: c),
    );
  }
}

class _LiveRoomBody extends StatelessWidget {
  const _LiveRoomBody({required this.controller});

  final LiveRoomController controller;

  double _scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / LiveRoomScreen._designWidth).clamp(0.85, 1.15);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scale(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final isChatInputActive = keyboardHeight > 0;
    final screenSize = MediaQuery.sizeOf(context);
    final bottomInset = keyboardHeight +
        (isChatInputActive ? 8 * scale : bottomPad + 8 * scale);
    final chatAreaBottom =
        bottomInset + LiveRoomScreen._inputBarHeight + LiveRoomScreen._chatGapAboveInput * scale;
    final chatOverlayTop = screenSize.height * LiveRoomScreen._chatOverlayTopFraction;
    final videoUpOffset = screenSize.height * LiveRoomScreen._contentUpShift;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.darkBackground,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) controller.onPopInvoked();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, -videoUpOffset),
                child: SizedBox(
                  width: screenSize.width,
                  height: screenSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Obx(() {
                        if (!controller.hasVideoUrl) {
                          return const LiveRoomVideoLoadingIndicator();
                        }
                        return LiveRoomVideoBackground(
                          key: controller.videoBackgroundKey,
                          videoUrl: controller.videoUrl.value,
                          alignment: LiveRoomScreen._videoAlignment,
                          onVideoReady: controller.onVideoReady,
                          onVideoFailed: controller.onVideoFailed,
                        );
                      }),
                      Obx(() {
                        if (!controller.hasVideoUrl || !controller.videoFailed.value) {
                          return const SizedBox.shrink();
                        }
                        return const _VideoUnavailableHint();
                      }),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0, 0.22, 0.55, 1],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Obx(
                  () => LiveRoomTopBar(
                    hostName: controller.hostName,
                    hostHandle: controller.hostHandle,
                    avatarUrl: controller.avatarUrl,
                    streamerEmail: controller.detail.value?.streamerEmail,
                    streamerId:
                        controller.detail.value?.streamerId ?? controller.preview.hostId,
                    onBack: () => controller.exitRoom(context),
                    onAboutTap: () => controller.onAboutTap(context),
                    onAvatarTap: () {
                      final id = (controller.detail.value?.streamerId ??
                              controller.preview.hostId)
                          ?.trim();
                      if (id == null || id.isEmpty) return;
                      openStarProfileForUser(
                        context,
                        userId: id,
                        name: controller.hostName,
                        email: controller.detail.value?.streamerEmail ??
                            controller.preview.hostEmail,
                        imageUrl: controller.avatarUrl,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: chatOverlayTop,
                bottom: chatAreaBottom,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  child: Obx(
                    () => LiveRoomChatPanel(
                      scale: scale,
                      messages: controller.messages.toList(),
                      scrollController: controller.chatScrollController,
                      communityNoticeText: LiveRoomController.communityNoticeText,
                      onUserMessageTap: (m) =>
                          controller.onChatMessageTap(context, m),
                    ),
                  ),
                ),
              ),
              Obx(() {
                final icon = controller.giftNotificationGiftIcon.value;
                if (icon == null) return const SizedBox.shrink();
                return Positioned(
                  left: 12 * scale,
                  top: chatOverlayTop +
                      LiveRoomScreen._giftBannerTopInsetDesign * scale,
                  child: IgnorePointer(
                    child: LiveGiftNotificationBanner(
                      scale: scale,
                      displayName: controller.giftSenderDisplayName,
                      avatarUrl: controller.giftNotificationAvatarUrl.value,
                      giftIconAsset: icon,
                    ),
                  ),
                );
              }),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: LiveRoomBottomBar(
                    chatController: controller.chatController,
                    onSend: () => controller.onSendChat(context),
                    onGift: () => controller.onGiftTap(context),
                    onViewers: () => controller.onViewersTap(context),
                    onMore: () => controller.onMoreTap(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoUnavailableHint extends StatelessWidget {
  const _VideoUnavailableHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Video unavailable.\nMake sure live-streams/.../video.mp4 is uploaded to Storage.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
