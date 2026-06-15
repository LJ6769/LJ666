// 按用户 id 或展示信息打开明星/用户详情页。
import 'package:flutter/material.dart';
import 'package:hilmi/core/foreground_media_pause.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/screens/star_profile_screen.dart';

/// 打开用户个人中心；会暂停底层直播/聊天室视频与朋友圈播放，返回后恢复。
Future<void> openStarProfile(
  BuildContext context, {
  required ProfileStory story,
}) async {
  await ForegroundMediaPause.pauseForOverlay();
  try {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StarProfileScreen(story: story),
      ),
    );
  } finally {
    await ForegroundMediaPause.resumeAfterOverlay();
  }
}

/// 由用户 id / 展示信息打开个人详情页。
Future<void> openStarProfileForUser(
  BuildContext context, {
  required String userId,
  String? name,
  String? email,
  String? imageUrl,
}) {
  final id = userId.trim();
  if (id.isEmpty) return Future<void>.value();
  return openStarProfile(
    context,
    story: ProfileStory(
      id: id,
      name: name,
      imageUrl: imageUrl,
      email: email,
    ),
  );
}
