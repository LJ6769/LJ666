// 直播画面中部礼物送出提示条。
import 'package:flutter/material.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

/// 直播画面中部礼物送出提示条（头像 + 昵称 + Send + 礼物图标）。
class LiveGiftNotificationBanner extends StatelessWidget {
  const LiveGiftNotificationBanner({
    super.key,
    required this.scale,
    required this.displayName,
    required this.giftIconAsset,
    this.avatarUrl,
  });

  final double scale;
  final String displayName;
  final String? avatarUrl;
  final String giftIconAsset;

  static const _bannerDesignHeight = 45.0;
  static const _bannerDesignWidth = 130.0;

  static double get designHeight => _bannerDesignHeight;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final height = _bannerDesignHeight * s;
    final width = _bannerDesignWidth * s;
    final avatarSize = 26 * s;
    final giftSize = 28 * s;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              LiveRoomAssets.giftNotifyBg,
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5 * s),
            child: Row(
              children: [
                ClipOval(
                  child: _AvatarThumb(
                    size: avatarSize,
                    url: avatarUrl,
                  ),
                ),
                SizedBox(width: 6 * s),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12 * s,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      Image.asset(
                        LiveRoomAssets.giftNotifySend,
                        height: 13 * s,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6 * s),
                Image.asset(
                  giftIconAsset,
                  width: giftSize,
                  height: giftSize,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarThumb extends StatelessWidget {
  const _AvatarThumb({required this.size, this.url});

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
