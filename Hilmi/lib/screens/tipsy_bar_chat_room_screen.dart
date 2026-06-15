// Tipsy Bar 语音聊天室：麦位、公屏、底部栏。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/tipsy_bar_chat_room_controller.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/data/tipsy_bar_chat_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/tipsy_bar_chat.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/follow/follow_action_button.dart';
import 'package:hilmi/widgets/host_info_bar.dart';
import 'package:hilmi/widgets/live_room/live_gift_notification_banner.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_chat_assets.dart';

/// Tipsy Bar 语音聊天室（点击卡片 Join in 进入）。
class TipsyBarChatRoomScreen extends StatelessWidget {
  const TipsyBarChatRoomScreen({
    super.key,
    required this.room,
    this.repository = const TipsyBarChatRepository(),
    this.openAboutRoomOnEnter = false,
  });

  final TipsyBarRoom room;
  final TipsyBarChatRepository repository;
  final bool openAboutRoomOnEnter;

  static const _designWidth = 375.0;
  static const _pageBackground = Color(0xFFFEFAEF);
  static const _giftBannerUpOffset = 80.0;

  @override
  Widget build(BuildContext context) {
    return GetxScreen<TipsyBarChatRoomController>(
      create: () => TipsyBarChatRoomController(
        room: room,
        repository: repository,
        openAboutRoomOnEnter: openAboutRoomOnEnter,
      ),
      builder: (c) => _TipsyBarChatRoomBody(controller: c),
    );
  }
}

class _TipsyBarChatRoomBody extends StatefulWidget {
  const _TipsyBarChatRoomBody({required this.controller});

  final TipsyBarChatRoomController controller;

  @override
  State<_TipsyBarChatRoomBody> createState() => _TipsyBarChatRoomBodyState();
}

class _TipsyBarChatRoomBodyState extends State<_TipsyBarChatRoomBody> {
  Worker? _aboutWorker;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _aboutWorker = ever(c.pendingAboutSheet, (open) {
      if (open != true || !mounted) return;
      c.pendingAboutSheet.value = false;
      unawaited(c.onMoreTap(context));
    });
  }

  @override
  void dispose() {
    _aboutWorker?.dispose();
    super.dispose();
  }

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / TipsyBarChatRoomScreen._designWidth;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = _s(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final screenSize = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: TipsyBarChatRoomScreen._pageBackground,
        body: Obx(
          () => c.loading.value
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD14D4D),
                    strokeWidth: 2,
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(
                        color: TipsyBarChatRoomScreen._pageBackground,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Image.asset(
                        TipsyBarChatAssets.bgBottom,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TipsyBarChatTopBar(
                            scale: s,
                            topInset: topInset,
                            host: c.detail.value?.host,
                            joinedSeat: c.joinedSeat.value,
                            micOn: c.micOn.value,
                            soundOn: c.soundOn.value,
                            onBack: () => Navigator.of(context).pop(),
                            onMicTap: c.onMicTap,
                            onSoundTap: c.onSoundTap,
                            onHostAvatarTap: (host) => c.openUserProfile(
                              context,
                              userId: host.userId,
                              name: host.displayName,
                              email: host.email,
                              imageUrl: host.avatarUrl,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  EdgeInsets.fromLTRB(12 * s, 4 * s, 8 * s, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _TipsyBarChatMessageList(
                                      scale: s,
                                      messages: c.messages.toList(),
                                      scrollController: c.chatScrollController,
                                      onUserMessageTap: (m) =>
                                          c.onChatMessageTap(context, m),
                                      onUserAvatarTap: (m) => c.openUserProfile(
                                        context,
                                        userId: m.senderId ?? '',
                                        name: m.senderName,
                                        imageUrl: m.avatarUrl,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8 * s),
                                  _TipsyBarSeatsColumn(
                                    scale: s,
                                    detail: c.detail.value,
                                    joinedSeat: c.joinedSeat.value,
                                    isRoomHost: c.isRoomHost,
                                    micOn: c.micOn.value,
                                    soundOn: c.soundOn.value,
                                    onJoinTap: () => c.onJoinSeat(context),
                                    onLeaveSeat: c.onLeaveSeat,
                                    onMemberAvatarTap: (member) =>
                                        c.openUserProfile(
                                      context,
                                      userId: member.userId,
                                      name: member.displayName,
                                      email: member.email,
                                      imageUrl: member.avatarUrl,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _TipsyBarChatBottomBar(
                            scale: s,
                            bottomInset: bottomInset,
                            controller: c.chatController,
                            onSend: () => c.onSend(context),
                            onGift: () => c.onGiftTap(context),
                            onMembers: () => c.onMembersTap(context),
                            onMore: () => c.onMoreTap(context),
                          ),
                        ],
                      ),
                    ),
                    if (c.giftNotificationGiftIcon.value != null)
                      Positioned(
                        left: 12 * s,
                        top: (screenSize.height -
                                    LiveGiftNotificationBanner.designHeight *
                                        s) /
                                2 -
                            TipsyBarChatRoomScreen._giftBannerUpOffset * s,
                        child: IgnorePointer(
                          child: LiveGiftNotificationBanner(
                            scale: s,
                            displayName: c.giftSenderDisplayName,
                            avatarUrl: c.giftNotificationAvatarUrl.value,
                            giftIconAsset: c.giftNotificationGiftIcon.value!,
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

class _TipsyBarChatTopBar extends StatelessWidget {
  const _TipsyBarChatTopBar({
    required this.scale,
    required this.topInset,
    required this.host,
    required this.joinedSeat,
    required this.micOn,
    required this.soundOn,
    required this.onBack,
    required this.onMicTap,
    required this.onSoundTap,
    required this.onHostAvatarTap,
  });

  final double scale;
  final double topInset;
  final TipsyBarChatMember? host;
  final bool joinedSeat;
  final bool micOn;
  final bool soundOn;
  final VoidCallback onBack;
  final VoidCallback onMicTap;
  final VoidCallback onSoundTap;
  final ValueChanged<TipsyBarChatMember> onHostAvatarTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final hostMember = host;

    return Padding(
      padding: EdgeInsets.fromLTRB(8 * s, 4 * s, 12 * s, 8 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnBack,
              width: 40 * s,
              height: 40 * s,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8 * s),
          if (hostMember != null)
            HostInfoBar(
              width: HostInfoBar.compactWidth * s,
              avatarUrl: hostMember.avatarUrl,
              avatarCacheKey: hostMember.avatarPath,
              name: hostMember.displayName,
              email: hostMember.email,
              userId: hostMember.userId,
              onAvatarTap: () => onHostAvatarTap(hostMember),
              trailing: FollowActionButton(
                userId: hostMember.userId,
                size: 28 * s,
                addAsset: TipsyBarChatAssets.btnFollowAdd,
                checkAsset: CircleAssets.btnFollowCheck,
              ),
            ),
          const Spacer(),
          if (joinedSeat && soundOn) ...[
            GestureDetector(
              onTap: onMicTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                micOn
                    ? TipsyBarChatAssets.icMicOn
                    : TipsyBarChatAssets.icMicOff,
                width: 40 * s,
                height: 40 * s,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 8 * s),
          ],
          GestureDetector(
            onTap: onSoundTap,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              soundOn
                  ? TipsyBarChatAssets.btnSound
                  : TipsyBarChatAssets.icSoundOff,
              width: 40 * s,
              height: 40 * s,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsyBarChatMessageList extends StatelessWidget {
  const _TipsyBarChatMessageList({
    required this.scale,
    required this.messages,
    required this.scrollController,
    this.onUserMessageTap,
    this.onUserAvatarTap,
  });

  final double scale;
  final List<TipsyBarChatMessage> messages;
  final ScrollController scrollController;
  final void Function(TipsyBarChatMessage message)? onUserMessageTap;
  final void Function(TipsyBarChatMessage message)? onUserAvatarTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: 12 * s),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        if (msg.isSystem) {
          return Padding(
            padding: EdgeInsets.only(bottom: 10 * s),
            child: _TipsBanner(scale: s, text: msg.text),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: 10 * s),
          child: _UserMessageBubble(
            scale: s,
            message: msg,
            onTap: onUserMessageTap == null ? null : () => onUserMessageTap!(msg),
            onAvatarTap: onUserAvatarTap == null
                ? null
                : () => onUserAvatarTap!(msg),
          ),
        );
      },
    );
  }
}

class _TipsBanner extends StatelessWidget {
  const _TipsBanner({required this.scale, required this.text});

  final double scale;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            TipsyBarChatAssets.icTips,
            width: 28 * s,
            height: 28 * s,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12 * s,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({
    required this.scale,
    required this.message,
    this.onTap,
    this.onAvatarTap,
  });

  final double scale;
  final TipsyBarChatMessage message;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final avatarSize = 32 * s;
    final canOpenProfile = message.senderId?.trim().isNotEmpty ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: canOpenProfile && onAvatarTap != null ? onAvatarTap : null,
          behavior: HitTestBehavior.opaque,
          child: ClipOval(
            child: message.avatarUrl != null && message.avatarUrl!.isNotEmpty
                ? CachedMediaImage(
                    url: message.avatarUrl!,
                    width: avatarSize,
                    height: avatarSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _avatarPlaceholder(avatarSize),
                  )
                : _avatarPlaceholder(avatarSize),
          ),
        ),
        SizedBox(width: 8 * s),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4 * s),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14 * s),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 13 * s,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder(double size) {
    return ColoredBox(
      color: const Color(0xFFE8E4DC),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.person, size: size * 0.5, color: Colors.black38),
      ),
    );
  }
}

class _TipsyBarSeatsColumn extends StatelessWidget {
  const _TipsyBarSeatsColumn({
    required this.scale,
    required this.detail,
    required this.joinedSeat,
    required this.isRoomHost,
    required this.micOn,
    required this.soundOn,
    required this.onJoinTap,
    required this.onLeaveSeat,
    required this.onMemberAvatarTap,
  });

  final double scale;
  final TipsyBarChatRoomDetail? detail;
  final bool joinedSeat;
  final bool isRoomHost;
  final bool micOn;
  final bool soundOn;
  final VoidCallback onJoinTap;
  final VoidCallback onLeaveSeat;
  final ValueChanged<TipsyBarChatMember> onMemberAvatarTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    const seatSize = 72.0;
    final slots = <_SeatSlot>[];

    // 麦位：1 房主，2–3 嘉宾，4–5 空位 Join in。
    final members = detail?.members ?? [];
    for (var i = 0; i < TipsyBarChatRoomDetail.seatCount; i++) {
      if (i < members.length && !members[i].isVacantSeat) {
        slots.add(_SeatSlot(member: members[i]));
      } else if (!isRoomHost &&
          i >= TipsyBarChatRoomDetail.joinSeatIndexStart &&
          joinedSeat &&
          i == members.length &&
          AuthService.cachedProfile != null) {
        final p = AuthService.cachedProfile!;
        slots.add(
          _SeatSlot(
            member: TipsyBarChatMember(
              userId: p.id,
              displayName: p.displayName,
              email: p.email,
              avatarUrl: p.avatarUrl,
              avatarPath: p.avatarPath,
              isSpeaking: micOn && soundOn,
            ),
            isSelf: true,
          ),
        );
      } else {
        slots.add(const _SeatSlot());
      }
    }

    return SizedBox(
      width: seatSize * s + 8,
      child: Column(
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0) SizedBox(height: 10 * s),
            _SeatTile(
              scale: s,
              size: seatSize * s,
              slot: slots[i],
              showMicIndicator: soundOn,
              showJoinIn: !joinedSeat &&
                  !isRoomHost &&
                  i >= TipsyBarChatRoomDetail.joinSeatIndexStart,
              onJoinTap: onJoinTap,
              onLeaveSeat: onLeaveSeat,
              onProfileTap: onMemberAvatarTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatSlot {
  const _SeatSlot({this.member, this.isSelf = false});

  final TipsyBarChatMember? member;
  final bool isSelf;
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.scale,
    required this.size,
    required this.slot,
    required this.showMicIndicator,
    required this.showJoinIn,
    required this.onJoinTap,
    required this.onLeaveSeat,
    required this.onProfileTap,
  });

  final double scale;
  final double size;
  final _SeatSlot slot;
  final bool showMicIndicator;
  final bool showJoinIn;
  final VoidCallback onJoinTap;
  final VoidCallback onLeaveSeat;
  final ValueChanged<TipsyBarChatMember> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final member = slot.member;

    if (member == null || member.isVacantSeat) {
      final joinInExtra = showJoinIn ? 28 * s : 0.0;
      return SizedBox(
        width: size,
        height: size + joinInExtra,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Image.asset(
              TipsyBarChatAssets.seatEmpty,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
            if (showJoinIn)
              Positioned(
                bottom: 0,
                child: GestureDetector(
                  onTap: onJoinTap,
                  behavior: HitTestBehavior.opaque,
                  child: Image.asset(
                    TipsyBarChatAssets.btnJoinIn,
                    height: 32 * s,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    const crownSize = 26.0;
    final crownH = crownSize * s;
    final hostTopPad = member.isHost ? crownH * 0.52 : 0.0;

    final userId = member.userId.trim();
    final canOpenProfile = userId.isNotEmpty;

    return SizedBox(
      width: size,
      height: size + hostTopPad,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          GestureDetector(
            onTap: canOpenProfile ? () => onProfileTap(member) : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: member.avatarUrl != null &&
                            member.avatarUrl!.isNotEmpty
                        ? CachedMediaImage(
                            url: member.avatarUrl!,
                            cacheKey: member.avatarPath,
                            fit: BoxFit.cover,
                          )
                        : ColoredBox(
                            color: const Color(0xFFE8E4DC),
                            child: Icon(Icons.person, size: size * 0.45),
                          ),
                  ),
                  if (showMicIndicator && member.isSpeaking)
                    ClipOval(
                      child: Image.asset(
                        TipsyBarChatAssets.icMicActive,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (member.isHost)
            Positioned(
              bottom: size - crownH * 0.38,
              left: size * 0.52,
              child: Image.asset(
                TipsyBarChatAssets.icCrown,
                width: crownH,
                height: crownH,
                fit: BoxFit.contain,
              ),
            ),
          if (slot.isSelf)
            Positioned(
              right: -2 * s,
              bottom: -2 * s,
              child: GestureDetector(
                onTap: onLeaveSeat,
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  TipsyBarChatAssets.icLeaveSeat,
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

class _TipsyBarChatBottomBar extends StatelessWidget {
  const _TipsyBarChatBottomBar({
    required this.scale,
    required this.bottomInset,
    required this.controller,
    required this.onSend,
    required this.onGift,
    required this.onMembers,
    required this.onMore,
  });

  static const _sendButtonSize = 34.0;

  final double scale;
  final double bottomInset;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onGift;
  final VoidCallback onMembers;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final sendSize = _sendButtonSize * s;

    return Padding(
      padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 8 * s + bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 48 * s,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24 * s),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TextStyle(
                        fontSize: 15 * s,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Please enter...',
                        hintStyle: TextStyle(
                          fontSize: 15 * s,
                          color: Colors.black.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(
                          left: 16 * s,
                          right: sendSize + 12 * s,
                          top: 12 * s,
                          bottom: 12 * s,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 7 * s),
                    child: GestureDetector(
                      onTap: onSend,
                      behavior: HitTestBehavior.opaque,
                      child: Image.asset(
                        TipsyBarChatAssets.btnSend,
                        width: sendSize,
                        height: sendSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8 * s),
          GestureDetector(
            onTap: onGift,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnGift,
              width: 44 * s,
              height: 44 * s,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8 * s),
          GestureDetector(
            onTap: onMembers,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnMembers,
              width: 44 * s,
              height: 44 * s,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8 * s),
          GestureDetector(
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnMore,
              width: 44 * s,
              height: 44 * s,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
