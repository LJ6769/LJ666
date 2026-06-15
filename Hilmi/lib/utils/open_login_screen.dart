// 导航打开登录页并暂停底层媒体播放。
import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/foreground_media_pause.dart';
import 'package:hilmi/screens/login_screen.dart';
import 'package:hilmi/utils/auth_routes.dart';

/// 打开登录页；成功登录返回 `true`。
/// 会暂停底层直播间视频 / 聊天室房主语音 / 朋友圈视频。
Future<bool?> openLoginScreen(BuildContext context) async {
  await ForegroundMediaPause.pauseForOverlay();
  try {
    return await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: AuthRoutes.login),
        builder: (_) => const LoginScreen(),
      ),
    );
  } finally {
    await ForegroundMediaPause.resumeAfterOverlay();
  }
}

/// 未登录则提示并打开登录页；成功登录后刷新资料。返回是否已登录。
Future<bool> ensureLoggedIn(
  BuildContext context, {
  String loginHint = 'Please sign in first',
}) async {
  if (AuthService.isLoggedIn) return true;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loginHint),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  final loggedIn = await openLoginScreen(context);
  if (loggedIn == true) {
    await AuthService.loadCurrentProfile(forceRefresh: true);
  }
  return AuthService.isLoggedIn;
}
