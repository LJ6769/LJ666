// 拉黑确认弹窗流程，成功后将用户加入黑名单。
import 'package:flutter/material.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/live_room/live_blacklist_confirm_dialog.dart';

/// 确认后等待拉黑完成再返回，保证返回上一页时黑名单已生效。
Future<bool> addUserToBlacklist(
  BuildContext context,
  String userId,
) async {
  if (!await ensureLoggedIn(context, loginHint: 'Please sign in to block users')) {
    return false;
  }
  if (!context.mounted) return false;

  final targetId = userId.trim();
  if (targetId.isEmpty) return false;

  if (BlockService.isBlocked(targetId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Already in blacklist'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
    return true;
  }

  final confirmed = await LiveBlacklistConfirmDialog.show(context);
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  final errorContext = Navigator.of(context, rootNavigator: true).context;
  try {
    await BlockService.block(targetId);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Added to blacklist'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
    return true;
  } catch (error) {
    if (errorContext.mounted) {
      await showAuthNoticeDialog(
        errorContext,
        message: messageFromAuthError(error),
      );
    }
    return false;
  }
}
