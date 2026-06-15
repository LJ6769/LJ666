// 直播间顶部：返回、Live 角标、主播信息。
import 'package:flutter/material.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/follow/follow_action_button.dart';
import 'package:hilmi/widgets/host_info_bar.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

/// 直播间顶部：左侧返回 + Live 角标纵向排列，右侧主播信息胶囊。
class LiveRoomTopBar extends StatelessWidget {
  const LiveRoomTopBar({
    super.key,
    required this.hostName,
    required this.hostHandle,
    this.avatarUrl,
    this.streamerEmail,
    required this.onBack,
    this.streamerId,
    this.onFollow,
    this.onAboutTap,
    this.onAvatarTap,
  });

  static const _borderWidth = 3.0;
  static const _backSize = 44.0;
  static const _backLiveInset = 10.0;
  static const _backToHostGap = 6.0;

  final String hostName;
  final String hostHandle;
  final String? avatarUrl;
  final String? streamerEmail;
  final VoidCallback onBack;
  final String? streamerId;
  final VoidCallback? onFollow;
  final VoidCallback? onAboutTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Padding(
        padding: const EdgeInsets.only(left: _backLiveInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BackButton(onTap: onBack),
                const SizedBox(width: _backToHostGap),
                HostInfoBar(
                  width: HostInfoBar.compactWidth,
                  avatarUrl: avatarUrl,
                  name: hostName,
                  email: streamerEmail,
                  userId: streamerId,
                  fallbackHandle: hostHandle,
                  onAvatarTap: onAvatarTap,
                  trailing: streamerId != null && streamerId!.trim().isNotEmpty
                      ? FollowActionButton(
                          userId: streamerId,
                          addAsset: LiveRoomAssets.follow,
                          checkAsset: CircleAssets.btnFollowCheck,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _LiveBadge(onTap: onAboutTap),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        LiveRoomAssets.back,
        width: LiveRoomTopBar._backSize,
        height: LiveRoomTopBar._backSize,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black,
          width: LiveRoomTopBar._borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFE53935),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Live',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return badge;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: badge,
    );
  }
}
