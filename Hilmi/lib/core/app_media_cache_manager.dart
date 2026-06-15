// Supabase 图片/视频本地磁盘缓存（30 天，原文件不压缩）。
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hilmi/config/config.dart';

/// Supabase 媒体文件磁盘缓存：以 Storage 对象路径为键，保留原画质。
abstract final class AppMediaCacheManager {
  static final CacheManager instance = CacheManager(
    Config(
      'hilmi_supabase_media',
      stalePeriod: SupabaseEgressConfig.mediaCacheTtl,
      maxNrOfCacheObjects: 800,
    ),
  );
}
