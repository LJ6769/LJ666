import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/home_shell.dart';

/// 退出登录并回到 [HomePage] 首页（Discover Tab）。
Future<void> logoutAndGoHome(BuildContext context) async {
  await AuthService.signOut();
  HomeShell.goToDiscoverHome();
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}
