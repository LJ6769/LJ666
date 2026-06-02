import 'package:flutter/material.dart';
import 'package:hilmi/models/live_chat_message.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

/// 直播间聊天区：顶部社区公告 + 可上下滑动的弹幕列表（对齐 Tjgo）。
class LiveRoomChatPanel extends StatelessWidget {
  const LiveRoomChatPanel({
    super.key,
    required this.scale,
    required this.messages,
    required this.scrollController,
    required this.communityNoticeText,
  });

  final double scale;
  final List<LiveChatMessage> messages;
  final ScrollController scrollController;
  final String communityNoticeText;

  static const _chatListPhysics = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(
      parent: ClampingScrollPhysics(),
    ),
  );

  static const _panelRadiusDesign = 12.0;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _CommunityNoticeBanner(
        scale: scale,
        text: communityNoticeText,
      ),
      SizedBox(height: 8 * scale),
    ];

    for (final msg in messages) {
      if (msg.isSystem) continue;
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: _UserBubble(
            scale: scale,
            senderId: msg.senderId,
            name: msg.displayName,
            text: msg.text,
            avatarUrl: msg.avatarUrl,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(_panelRadiusDesign * scale),
      child: ListView(
        controller: scrollController,
        physics: _chatListPhysics,
        padding: EdgeInsets.all(8 * scale),
        children: children,
      ),
    );
  }
}

class _CommunityNoticeBanner extends StatelessWidget {
  const _CommunityNoticeBanner({
    required this.scale,
    required this.text,
  });

  final double scale;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F).withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            LiveRoomAssets.tipsMegaphone,
            width: 22 * scale,
            height: 22 * scale,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFFFFE082),
                fontSize: 11 * scale,
                height: 1.35,
                fontWeight: FontWeight.w500,
                shadows: const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.scale,
    this.senderId,
    required this.name,
    required this.text,
    this.avatarUrl,
  });

  final double scale;
  final String? senderId;
  final String name;
  final String text;
  final String? avatarUrl;

  void _onAvatarTap(BuildContext context) {
    final id = senderId?.trim();
    if (id == null || id.isEmpty) return;
    openStarProfileForUser(
      context,
      userId: id,
      name: name,
      imageUrl: avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = 28 * scale;
    final canOpenProfile = senderId?.trim().isNotEmpty ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: canOpenProfile ? () => _onAvatarTap(context) : null,
          behavior: HitTestBehavior.opaque,
          child: ClipOval(
            child: _AvatarImage(url: avatarUrl, size: avatarSize),
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * scale,
                  vertical: 8 * scale,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10 * scale),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12 * scale,
                    height: 1.35,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.size, this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedMediaImage(
        url: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(size),
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return ColoredBox(
      color: const Color(0xFF2A1F4A),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.person, size: size * 0.55, color: Colors.white38),
      ),
    );
  }
}
