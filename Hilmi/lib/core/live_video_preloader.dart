// 点击直播卡时预加载视频（流式初始化 + 后台缓存），进房复用 VideoPlayerController。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hilmi/services/cached_media_file_loader.dart';
import 'package:video_player/video_player.dart';

class _PreloadEntry {
  _PreloadEntry({
    required this.cacheKey,
    required this.controller,
  }) : initFuture = _prepare(controller);

  final String cacheKey;
  final VideoPlayerController controller;
  final Future<void> initFuture;

  static Future<void> _prepare(VideoPlayerController controller) async {
    await controller.initialize();
    await controller.setLooping(true);
  }
}

/// 点击直播卡片时预加载视频，进房后复用控制器，首帧无需等整文件下载完成。
abstract final class LiveVideoPreloader {
  static final _pending = <String, _PreloadEntry>{};

  static String _resolveCacheKey(String url, [String? cacheKey]) {
    return CachedMediaFileLoader.resolveKey(url, cacheKey);
  }

  static void start(String? url, {String? cacheKey}) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return;

    final key = _resolveCacheKey(normalized, cacheKey);
    if (_pending.containsKey(key)) return;
    unawaited(_startPreload(normalized, key));
  }

  static Future<void> _startPreload(String url, String cacheKey) async {
    if (_pending.containsKey(cacheKey)) return;

    try {
      final controller = await CachedMediaFileLoader.createVideoController(
        url: url,
        cacheKey: cacheKey,
      );
      final entry = _PreloadEntry(cacheKey: cacheKey, controller: controller);
      _pending[cacheKey] = entry;
      await entry.initFuture;
    } catch (error, stack) {
      debugPrint('[LiveVideoPreloader] preload failed: $error');
      debugPrint('$stack');
      final entry = _pending.remove(cacheKey);
      await entry?.controller.dispose();
    }
  }

  static Future<VideoPlayerController?> claim(
    String? url, {
    String? cacheKey,
  }) async {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return null;

    final key = _resolveCacheKey(normalized, cacheKey);
    final entry = _pending.remove(key);
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

  static void discard(String? url, {String? cacheKey}) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) return;
    final key = _resolveCacheKey(normalized, cacheKey);
    final entry = _pending.remove(key);
    if (entry == null) return;
    unawaited(_release(entry.controller));
  }

  static void disposeAll() {
    final entries = _pending.values.toList(growable: false);
    _pending.clear();
    for (final entry in entries) {
      unawaited(_release(entry.controller));
    }
  }

  static Future<void> _release(VideoPlayerController controller) async {
    try {
      if (controller.value.isInitialized) {
        await controller.pause();
        await controller.setVolume(0);
      }
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }
}
