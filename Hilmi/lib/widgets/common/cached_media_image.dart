import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hilmi/utils/media_url.dart';

/// 远程图片（Supabase Storage 等）：磁盘 + 内存缓存，减少重复 egress。
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
        await DefaultCacheManager().removeFile(key);
      } catch (_) {}
    }

    final imageUrl = url?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await CachedNetworkImage.evictFromCache(imageUrl);
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

    final dpr = MediaQuery.devicePixelRatioOf(context);
    int? memCacheWidth;
    int? memCacheHeight;
    if (width != null && width!.isFinite && width! > 0) {
      memCacheWidth = (width! * dpr).round().clamp(1, 2048);
    }
    if (height != null && height!.isFinite && height! > 0) {
      memCacheHeight = (height! * dpr).round().clamp(1, 2048);
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: resolvedCacheKey,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: memCacheWidth,
      maxHeightDiskCache: memCacheHeight,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
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
