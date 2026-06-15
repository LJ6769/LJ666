// 带磁盘/内存缓存的远程图片组件（原画质，减 Storage egress）。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hilmi/core/app_media_cache_manager.dart';
import 'package:hilmi/utils/media_url.dart';

/// 远程图片（Supabase Storage 等）：磁盘 + 内存缓存，保留原文件画质。
class CachedMediaImage extends StatelessWidget {
  const CachedMediaImage({
    super.key,
    required this.url,
    this.cacheKey,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.placeholder,
    this.errorBuilder,
  });

  final String url;

  /// Storage 对象路径；未传时从 [url] 解析。与 Signed URL 解耦，避免 token 轮换导致重复下载。
  final String? cacheKey;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// 换图后清除磁盘/内存缓存（[cacheKey] 一般为 Storage 对象路径）。
  static Future<void> evict({String? url, String? cacheKey}) async {
    final key = cacheKey?.trim();
    if (key != null && key.isNotEmpty) {
      try {
        await AppMediaCacheManager.instance.removeFile(key);
      } catch (_) {}
    }

    final imageUrl = url?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await CachedNetworkImage.evictFromCache(
          imageUrl,
          cacheKey: key,
          cacheManager: AppMediaCacheManager.instance,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      if (errorBuilder != null) {
        return errorBuilder!(context, Object(), StackTrace.current);
      }
      return const SizedBox.shrink();
    }

    final resolvedCacheKey =
        cacheKey?.trim().isNotEmpty == true
            ? cacheKey!.trim()
            : storagePathFromMediaUrl(url);

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: resolvedCacheKey,
      cacheManager: AppMediaCacheManager.instance,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      useOldImageOnUrlChange: true,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: placeholder == null
          ? null
          : (context, url) => placeholder!,
      errorWidget: errorBuilder == null
          ? null
          : (context, url, error) =>
              errorBuilder!(context, error, StackTrace.current),
    );
  }
}
