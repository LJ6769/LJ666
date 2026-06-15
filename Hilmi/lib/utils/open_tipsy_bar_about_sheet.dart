// Tipsy Bar 卡 / 聊天室共用 About 更多弹窗。
import 'package:flutter/material.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_about_room_sheet.dart';

/// 打开与聊天室「更多」相同的 About 弹窗。
///
/// 使用卡片已有数据立即弹出，避免点击后等待网络请求。
Future<TipsyBarMoreResult?> openTipsyBarAboutSheet(
  BuildContext context,
  TipsyBarRoom room,
) {
  return TipsyBarAboutRoomSheet.show(
    context,
    roomId: room.id,
    title: room.title ?? '',
    intro: room.description,
    hostUserId: room.hostUserId,
  );
}
