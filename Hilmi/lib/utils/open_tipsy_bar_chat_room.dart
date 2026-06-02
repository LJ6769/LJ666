import 'package:flutter/material.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/screens/tipsy_bar_chat_room_screen.dart';

/// 进入聊天室；若房间内删除了该房，返回 `true`。
///
/// [openAboutRoomOnEnter] 为 true 时进入后自动弹出 About Room 菜单。
Future<bool> openTipsyBarChatRoom(
  BuildContext context, {
  required TipsyBarRoom room,
  bool openAboutRoomOnEnter = false,
}) async {
  final deleted = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => TipsyBarChatRoomScreen(
        room: room,
        openAboutRoomOnEnter: openAboutRoomOnEnter,
      ),
    ),
  );
  return deleted == true;
}
