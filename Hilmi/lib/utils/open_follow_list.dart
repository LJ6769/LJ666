// 导航打开我的关注列表。
import 'package:flutter/material.dart';
import 'package:hilmi/screens/follow_list_screen.dart';

Future<void> openFollowListScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => const FollowListScreen(),
    ),
  );
}
