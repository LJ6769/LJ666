// 清除应用内本地与内存缓存（不含登录会话与 EULA）。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hilmi/core/app_media_cache_manager.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 清除应用内各类本地/内存缓存（不含 EULA、不含 Supabase 登录会话）。
///
/// 退出登录请使用 [AuthService.clearAuthSession]。
abstract final class LocalCacheService {
  /// 估算媒体磁盘缓存大小（字节）。
  static Future<int> estimateCacheBytes() async {
    try {
      final tmp = await getTemporaryDirectory();
      var total = 0;
      for (final name in ['libCachedImageData', 'hilmi_supabase_media']) {
        final cacheDir = Directory('${tmp.path}/$name');
        if (await cacheDir.exists()) {
          total += await _directorySize(cacheDir);
        }
      }
      return total;
    } catch (error, stack) {
      debugPrint('[LocalCacheService] estimateCacheBytes: $error');
      debugPrint('$stack');
      return 0;
    }
  }

  static String formatCacheSize(int bytes) {
    if (bytes <= 0) return '0M';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.round()}M';
    final kb = bytes / 1024;
    if (kb >= 1) return '${kb.round()}K';
    return '${bytes}B';
  }

  static Future<int> _directorySize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static Future<void> clearAll() async {
    FeedDataCache.clearAll();
    StorageMediaUrlResolver.clearCache();
    ViewerSession.reset();
    LiveVideoPreloader.disposeAll();

    imageCache.clear();
    imageCache.clearLiveImages();

    try {
      await AppMediaCacheManager.instance.emptyCache();
    } catch (error, stack) {
      debugPrint('[LocalCacheService] emptyCache failed: $error');
      debugPrint('$stack');
    }

    await _clearPendingAvatars();
  }

  static Future<void> _clearPendingAvatars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('pending_avatar_'))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (error, stack) {
      debugPrint('[LocalCacheService] clear pending avatars failed: $error');
      debugPrint('$stack');
    }
  }
}
