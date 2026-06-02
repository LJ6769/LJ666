import 'package:flutter/material.dart';
import 'package:hilmi/utils/user_handle.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';

/// 主播/作者信息胶囊（首页 Live 卡、朋友圈帖子叠层等共用）。
class HostInfoBar extends StatelessWidget {
  /// 标准总宽度（与首页 Live 卡一致，避免在宽父级里被撑满）。
  static const compactWidth = 130.0;

  const HostInfoBar({
    super.key,
    this.avatarUrl,
    this.avatarCacheKey,
    required this.name,
    this.email,
    this.userId,
    this.fallbackHandle,
    this.trailing,
    this.onAvatarTap,
    this.width,
    this.avatarSize = 28,
  });

  final String? avatarUrl;
  final String? avatarCacheKey;
  final String name;
  final String? email;
  final String? userId;
  final String? fallbackHandle;
  final Widget? trailing;
  final VoidCallback? onAvatarTap;

  /// 为 null 时按内容自适应（较窄文案区）；一般请传 [compactWidth]。
  final double? width;
  final double avatarSize;

  static const _borderWidth = 2.0;
  static const _radius = 18.0;
  static const _padding = EdgeInsets.all(5);

  String get _displayHandle {
    if (email != null || (userId != null && userId!.isNotEmpty)) {
      return formatUserHandle(email: email, userId: userId);
    }
    final fallback = fallbackHandle?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return '@user';
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: Colors.black, width: _borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarTapTarget(
            child: ClipOval(
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: _buildAvatar(),
              ),
            ),
          ),
          SizedBox(width: avatarSize >= 32 ? 8 : 5),
          _NameHandleColumn(
            name: name,
            handle: _displayHandle,
            avatarSize: avatarSize,
            expand: width != null,
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: bar);
    }
    return bar;
  }

  Widget _buildAvatarTapTarget({required Widget child}) {
    if (onAvatarTap == null) return child;
    return GestureDetector(
      onTap: onAvatarTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  Widget _buildAvatar() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CachedMediaImage(
        url: avatarUrl!,
        cacheKey: avatarCacheKey,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _avatarPlaceholder(),
      );
    }
    return _avatarPlaceholder();
  }

  Widget _avatarPlaceholder() {
    return ColoredBox(
      color: const Color(0xFFE8E4DC),
      child: Icon(
        Icons.person,
        size: avatarSize * 0.55,
        color: const Color(0xFF9E9E9E),
      ),
    );
  }
}

class _NameHandleColumn extends StatelessWidget {
  const _NameHandleColumn({
    required this.name,
    required this.handle,
    required this.avatarSize,
    required this.expand,
  });

  final String name;
  final String handle;
  final double avatarSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: avatarSize >= 32 ? 13 : 12,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            height: 1.1,
          ),
        ),
        Text(
          handle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: avatarSize >= 32 ? 11 : 10,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF757575),
            height: 1.1,
          ),
        ),
      ],
    );

    if (expand) {
      return Expanded(child: column);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 72),
      child: column,
    );
  }
}
