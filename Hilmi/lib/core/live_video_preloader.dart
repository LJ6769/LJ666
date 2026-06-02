import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class _PreloadEntry {
  _PreloadEntry(this.controller) : initFuture = _prepare(controller);

  final VideoPlayerController controller;
  final Future<void> initFuture;

  static Future<void> _prepare(VideoPlayerController controller) async {
    await controller.initialize();
    await controller.setLooping(true);
  }
}

/// 点击直播卡片时预加载视频，进房后复用控制器，避免重复 initialize。
abstract final class LiveVideoPreloader {
  static final _pending = <String, _PreloadEntry>{};

  static void start(String? url) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return;
    if (_pending.containsKey(normalized)) return;
    _startPreload(normalized);
  }

  static void _startPreload(String normalized) {
    if (_pending.containsKey(normalized)) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(normalized));
    final entry = _PreloadEntry(controller);
    _pending[normalized] = entry;
    entry.initFuture.catchError((Object error, StackTrace stack) {
      debugPrint('[LiveVideoPreloader] preload failed: $error');
      debugPrint('$stack');
      final current = _pending[normalized];
      if (current?.controller == controller) {
        _pending.remove(normalized);
      }
      controller.dispose();
    });
  }

  static Future<VideoPlayerController?> claim(String? url) async {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return null;

    final entry = _pending.remove(normalized);
    if (entry == null) return null;

    try {
      await entry.initFuture;
      if (!entry.controller.value.isInitialized) {
        await entry.controller.dispose();
        return null;
      }
      return entry.controller;
    } catch (error, stack) {
      debugPrint('[LiveVideoPreloader] claim failed: $error');
      debugPrint('$stack');
      await entry.controller.dispose();
      return null;
    }
  }

  static void discard(String? url) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return;
    _pending.remove(normalized)?.controller.dispose();
  }

  static void disposeAll() {
    for (final entry in _pending.values) {
      entry.controller.dispose();
    }
    _pending.clear();
  }
}
