import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/screens/coins_store_screen.dart';
import 'package:hilmi/utils/open_login_screen.dart';

/// 打开金币商城；未登录时先跳转登录。
Future<void> openCoinsStore(BuildContext context) async {
  if (!AuthService.isLoggedIn) {
    final loggedIn = await openLoginScreen(context);
    if (loggedIn != true) return;
    await AuthService.loadCurrentProfile();
  }
  if (!context.mounted) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const CoinsStoreScreen(),
    ),
  );
}
