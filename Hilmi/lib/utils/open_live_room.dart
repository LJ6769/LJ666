// 导航进直播间：先跳转再后台签名/预加载，避免点击后卡住。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/data/live_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/screens/live_room_screen.dart';
import 'package:hilmi/utils/is_uuid.dart';

/// 淡入路由，缩短转场时间，减轻进/退房与视频初始化的叠帧卡顿。
class _LiveRoomRoute<T> extends PageRouteBuilder<T> {
  _LiveRoomRoute({
    required RouteSettings settings,
    required WidgetBuilder builder,
  }) : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(opacity: curved, child: child);
          },
        );
}

/// 打开直播间：立即跳转，视频 URL 签名与预加载在后台进行。
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
    if (cached.isNotEmpty) {
      LiveVideoPreloader.start(cached);
    } else {
      unawaited(_prefetchVideo(room.id, liveRepository));
    }

    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      _LiveRoomRoute<void>(
        settings: RouteSettings(name: 'live_room/${room.id}'),
        builder: (_) => LiveRoomScreen(
          preview: room,
          initialVideoUrl: cached.isNotEmpty ? cached : null,
          liveRepository: liveRepository,
        ),
      ),
    );

    if (cached.isNotEmpty) {
      LiveVideoPreloader.discard(cached);
    }
  } finally {
    _liveRoomNavigationLock = false;
  }
}

Future<void> _prefetchVideo(String liveId, LiveRepository repository) async {
  final videoUrl = await repository.resolveVideoUrl(liveId);
  if (videoUrl.isNotEmpty) {
    LiveVideoPreloader.start(videoUrl);
  }
}

bool _liveRoomNavigationLock = false;
