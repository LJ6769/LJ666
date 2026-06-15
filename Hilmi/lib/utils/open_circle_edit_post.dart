// 导航打开发帖页；未登录先跳登录。
import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/screens/circle_edit_post_screen.dart';
import 'package:hilmi/utils/open_login_screen.dart';

/// 打开朋友圈发帖页；未登录时先进入登录页。
///
/// 发布成功返回 `true`，否则返回 `false`。
Future<bool> openCircleEditPost(BuildContext context) async {
  if (!AuthService.isLoggedIn) {
    final loggedIn = await openLoginScreen(context);
    if (loggedIn != true) return false;
  }

  if (!context.mounted) return false;

  final published = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => const CircleEditPostScreen(),
    ),
  );
  return published == true;
}
