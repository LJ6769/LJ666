import 'package:flutter/material.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/data/live_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/screens/live_room_screen.dart';
import 'package:hilmi/utils/is_uuid.dart';

/// 打开直播间：先签名 video（不下载），预加载后跳转；首页列表不拉视频。
///
/// 解析视频是异步的，连点卡片会多次 [Navigator.push]；用导航锁保证同时只进一次。
Future<void> openLiveRoom(
  BuildContext context,
  LiveRoom room, {
  LiveRepository liveRepository = const LiveRepository(),
}) async {
  if (_liveRoomNavigationLock) return;
  _liveRoomNavigationLock = true;

  try {
    if (!isUuid(room.id)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live data not loaded. Pull to refresh on Home and try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (BlockService.isBlocked(room.hostId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This host is blocked'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final cached = room.videoUrl?.trim() ?? '';
    final videoUrl = cached.isNotEmpty
        ? cached
        : await liveRepository.resolveVideoUrl(room.id);
    if (videoUrl.isNotEmpty) {
      LiveVideoPreloader.start(videoUrl);
    }

    if (!context.mounted) {
      LiveVideoPreloader.discard(videoUrl);
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'live_room/${room.id}'),
        builder: (_) => LiveRoomScreen(
          preview: room,
          initialVideoUrl: videoUrl.isNotEmpty ? videoUrl : null,
          liveRepository: liveRepository,
        ),
      ),
    );

    LiveVideoPreloader.discard(videoUrl);
  } finally {
    _liveRoomNavigationLock = false;
  }
}

bool _liveRoomNavigationLock = false;
