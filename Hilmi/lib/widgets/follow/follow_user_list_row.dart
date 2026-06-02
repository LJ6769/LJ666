import 'package:flutter/material.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/follow/follow_assets.dart';

/// 关注 / 粉丝列表中的用户行（卡片底图 + 头像 + 信息 + 自定义关注区 + 视频/私信）。
class FollowUserListRow extends StatelessWidget {
  const FollowUserListRow({
    super.key,
    required this.scale,
    required this.user,
    required this.followButton,
    required this.onVideoTap,
    required this.onMessageTap,
  });

  final double scale;
  final FollowUser user;
  final Widget followButton;
  final VoidCallback onVideoTap;
  final VoidCallback onMessageTap;

  static const rowAspect = 1005 / 201;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / rowAspect;

        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                FollowAssets.rowBg,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12 * s),
                child: Row(
                  children: [
                    _Avatar(scale: s, user: user),
                    SizedBox(width: 10 * s),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16 * s,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 2 * s),
                          Text(
                            user.handle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13 * s,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    followButton,
                    SizedBox(width: 6 * s),
                    _CircleActionButton(
                      scale: s,
                      asset: FollowAssets.btnVideo,
                      onTap: onVideoTap,
                    ),
                    SizedBox(width: 6 * s),
                    _CircleActionButton(
                      scale: s,
                      asset: FollowAssets.btnMessage,
                      onTap: onMessageTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FollowListFollowButtonSlot extends StatelessWidget {
  const FollowListFollowButtonSlot({
    super.key,
    required this.scale,
    required this.child,
  });

  final double scale;
  final Widget child;

  static const _followAspect = 270 / 108;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return SizedBox(
      width: 90 * s,
      height: 90 * s / _followAspect,
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.scale, required this.user});

  final double scale;
  final FollowUser user;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final size = 48 * s;
    final radius = 12 * s;

    Widget child;
    if (user.hasAvatar && user.avatarUrl != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedMediaImage(
          url: user.avatarUrl!,
          cacheKey: user.avatarPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _placeholder(size, radius),
        ),
      );
    } else {
      child = _placeholder(size, radius);
    }

    final userId = user.id.trim();
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: userId.isEmpty
            ? null
            : () => openStarProfileForUser(
                  context,
                  userId: userId,
                  name: user.displayName,
                  email: user.email,
                  imageUrl: user.avatarUrl,
                ),
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }

  Widget _placeholder(double size, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        FollowAssets.avatarPlaceholder,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.scale,
    required this.asset,
    required this.onTap,
  });

  final double scale;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = 36 * scale;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
