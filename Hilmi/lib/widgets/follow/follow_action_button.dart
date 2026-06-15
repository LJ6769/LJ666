// 关注/已关注图标按钮（同步 FollowService）。
import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/utils/auth_error_message.dart';

/// 关注 / 已关注图标按钮（同步 [FollowService]）。
class FollowActionButton extends StatelessWidget {
  const FollowActionButton({
    super.key,
    required this.userId,
    this.size = 28,
    this.addAsset = CircleAssets.btnFollowAdd,
    this.checkAsset = CircleAssets.btnFollowCheck,
  });

  final String? userId;
  final double size;
  final String addAsset;
  final String checkAsset;

  /// 当前会话中的「自己」（登录资料或访客随机身份）。
  static bool isSelfUserId(String? userId) {
    final targetId = userId?.trim() ?? '';
    if (targetId.isEmpty) return false;

    final profileId = AuthService.cachedProfile?.id.trim();
    if (profileId != null && profileId.isNotEmpty && profileId == targetId) {
      return true;
    }

    final sessionId = ViewerSession.current?.id.trim();
    if (sessionId != null && sessionId.isNotEmpty && sessionId == targetId) {
      return true;
    }

    return false;
  }

  static Future<void> handleTap(BuildContext context, String? userId) async {
    final targetId = userId?.trim() ?? '';
    if (targetId.isEmpty) return;
    if (isSelfUserId(targetId)) return;

    if (!AuthService.isLoggedIn) {
      final loggedIn = await openLoginScreen(context);
      if (!context.mounted || loggedIn != true) return;
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }

    try {
      await FollowService.toggle(targetId);
    } catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetId = userId?.trim() ?? '';
    if (targetId.isEmpty) return SizedBox(width: size, height: size);

    if (isSelfUserId(targetId)) {
      return SizedBox(width: size, height: size);
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: FollowService.followedIds,
      builder: (context, ids, child) {
        final followed = ids.contains(targetId);
        return GestureDetector(
          onTap: () => handleTap(context, targetId),
          behavior: HitTestBehavior.opaque,
          child: Image.asset(
            followed ? checkAsset : addAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
