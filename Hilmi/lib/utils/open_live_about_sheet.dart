// Live 卡 / 直播间共用 About 更多弹窗。
import 'package:flutter/material.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/live_stream_detail.dart';
import 'package:hilmi/utils/live_room_about_tags.dart';
import 'package:hilmi/widgets/live_room/live_about_sheet.dart';

/// 打开与直播间「更多」相同的 About 弹窗；拉黑成功时返回 `true`。
Future<bool> openLiveAboutSheet(BuildContext context, LiveRoom room) {
  return showLiveAboutSheet(
    context,
    description: room.description ?? room.title,
    categorySlug: room.categorySlug,
    categoryName: room.categoryName,
    tags: room.tags,
    streamerId: room.hostId,
  );
}

/// 直播间内 About（与 Live 卡共用同一套展示逻辑）。
Future<bool> openLiveAboutSheetFromDetail(
  BuildContext context,
  LiveStreamDetail detail, {
  String? streamerId,
}) {
  return showLiveAboutSheet(
    context,
    description: detail.description,
    categorySlug: detail.categorySlug,
    categoryName: detail.categoryName,
    tags: detail.tags,
    streamerId: streamerId ?? detail.streamerId,
  );
}

/// Live 卡 / 直播间统一 About 弹窗入口。
Future<bool> showLiveAboutSheet(
  BuildContext context, {
  String? description,
  String? categorySlug,
  String? categoryName,
  List<String> tags = const [],
  required String? streamerId,
}) {
  final displayTags = LiveRoomAboutTags.build(
    categorySlug: categorySlug,
    categoryName: categoryName,
    tags: tags,
  );

  return LiveAboutSheet.show(
    context,
    description: description,
    tags: displayTags,
    streamerId: streamerId,
  );
}
