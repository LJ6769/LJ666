import 'package:flutter/material.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/live_room/live_blacklist_confirm_dialog.dart';

/// 确认后将用户加入黑名单；成功返回 `true`。
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already in blacklist'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
    return true;
  }

  final confirmed = await LiveBlacklistConfirmDialog.show(context);
  if (confirmed != true || !context.mounted) return false;

  try {
    await BlockService.block(targetId);
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to blacklist'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    await showAuthNoticeDialog(
      context,
      message: messageFromAuthError(error),
    );
    return false;
  }
}
