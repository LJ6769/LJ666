// 导航打开注册页。
import 'package:flutter/material.dart';
import 'package:hilmi/screens/signup_screen.dart';
import 'package:hilmi/utils/auth_routes.dart';

/// 打开注册页；注册成功返回 `true`。
Future<bool?> openSignupScreen(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      settings: const RouteSettings(name: AuthRoutes.signup),
      builder: (_) => const SignupScreen(),
    ),
  );
}
