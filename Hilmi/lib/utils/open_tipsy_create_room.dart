// 导航打开创建 Tipsy Bar 房间页。
import 'package:flutter/material.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/screens/tipsy_create_room_screen.dart';
/// 打开 Tipsy Bar 创建聊天室页；成功创建返回 [TipsyBarRoom]。
Future<TipsyBarRoom?> openTipsyCreateRoom(BuildContext context) {
  return Navigator.of(context).push<TipsyBarRoom>(
    MaterialPageRoute(
      builder: (_) => const TipsyCreateRoomScreen(),
    ),
  );
}
