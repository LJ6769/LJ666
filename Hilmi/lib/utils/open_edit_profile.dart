// 导航打开编辑资料页。
import 'package:flutter/material.dart';
import 'package:hilmi/screens/edit_profile_screen.dart';

/// 打开编辑资料页；保存成功返回 `true`。
Future<bool?> openEditProfileScreen(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (context) => const EditProfileScreen(),
    ),
  );
}
