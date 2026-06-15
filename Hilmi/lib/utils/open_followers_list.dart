// 导航打开我的粉丝列表。
import 'package:flutter/material.dart';
import 'package:hilmi/screens/followers_list_screen.dart';

Future<void> openFollowersListScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => const FollowersListScreen(),
    ),
  );
}
