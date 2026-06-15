// 媒体本地缓存：图片全量下载；视频优先流式播放并后台写入缓存。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_media_cache_manager.dart';
import 'package:hilmi/utils/media_url.dart';
import 'package:video_player/video_player.dart';

abstract final class CachedMediaFileLoader {
  static final Set<String> _backgroundCacheKeys = <String>{};
  static String resolveKey(String url, [String? cacheKey]) {
    final trimmedKey = cacheKey?.trim() ?? '';
    if (trimmedKey.isNotEmpty) return trimmedKey;
    return storagePathFromMediaUrl(url) ?? url.trim();
  }

  /// 仅读本地缓存；命中则无需重新签名或下载。
  static Future<File?> getFromCacheOnly(String? cacheKey) async {
    final key = cacheKey?.trim() ?? '';
    if (key.isEmpty) return null;
    final info = await AppMediaCacheManager.instance.getFileFromCache(key);
    return info?.file;
  }

  /// 优先本地缓存；未命中则从 [url] 下载原文件并写入缓存。
  static Future<File> getFile({
    required String url,
    String? cacheKey,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(url, 'url', 'cannot be empty');
    }
    final key = resolveKey(trimmed, cacheKey);
    return AppMediaCacheManager.instance.getSingleFile(trimmed, key: key);
  }

  /// 视频播放：缓存命中走本地文件，否则网络流式播放并后台缓存。
  static Future<VideoPlayerController> createVideoController({
    required String url,
    String? cacheKey,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(url, 'url', 'cannot be empty');
    }
    final key = resolveKey(trimmed, cacheKey);
    final cached = key.isNotEmpty ? await getFromCacheOnly(key) : null;
    if (cached != null) {
      return VideoPlayerController.file(cached);
    }

    cacheInBackground(url: trimmed, cacheKey: key);
    return VideoPlayerController.networkUrl(Uri.parse(trimmed));
  }

  /// 后台写入磁盘缓存，供下次播放直接命中本地文件。
  static void cacheInBackground({
    required String url,
    String? cacheKey,
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final key = resolveKey(trimmed, cacheKey);
    if (key.isEmpty || _backgroundCacheKeys.contains(key)) return;

    _backgroundCacheKeys.add(key);
    unawaited(
      _cacheInBackground(url: trimmed, cacheKey: key).whenComplete(
        () => _backgroundCacheKeys.remove(key),
      ),
    );
  }

  static Future<void> _cacheInBackground({
    required String url,
    required String cacheKey,
  }) async {
    try {
      final existing =
          await AppMediaCacheManager.instance.getFileFromCache(cacheKey);
      if (existing != null) return;
      await AppMediaCacheManager.instance.downloadFile(url, key: cacheKey);
    } catch (error, stack) {
      debugPrint('[CachedMediaFileLoader] background cache failed: $error');
      debugPrint('$stack');
    }
  }
}
