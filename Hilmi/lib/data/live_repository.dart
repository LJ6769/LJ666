// 直播间详情拉取（进房时才签名 video URL）。
import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/live_stream_detail.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:hilmi/utils/is_uuid.dart';

/// 直播间数据：视频仅在进房时签名，首页不调用。
class LiveRepository {
  const LiveRepository();

  /// 仅解析并签名 [video_path]，供点击卡片时预加载。
  Future<String> resolveVideoUrl(String liveId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return '';
    if (!isUuid(liveId)) return '';

    try {
      final row = await client
          .from(SupabaseTables.live)
          .select('video_path')
          .eq('id', liveId)
          .maybeSingle();
      if (row == null) return '';
      final path = row['video_path'] as String?;
      if (path == null || path.isEmpty) return '';
      return StorageMediaUrlResolver.resolve(path, client: client);
    } catch (error, stack) {
      debugPrint('[LiveRepository] resolveVideoUrl: $error');
      debugPrint('$stack');
      return '';
    }
  }

  /// 进房后拉取详情（含头像/视频签名 URL；封面默认签名，可关闭）。
  Future<LiveStreamDetail?> fetchRoomDetail(
    String liveId, {
    bool includeCover = true,
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;
    if (!isUuid(liveId)) return null;

    try {
      final row = await client
          .from(SupabaseTables.live)
          .select('''
            id,
            description,
            cover_path,
            video_path,
            viewer_count,
            is_live,
            streamer_id,
            category_slug,
            category_name,
            tags,
            User!streamer_id (
              display_name,
              email,
              avatar_path
            )
          ''')
          .eq('id', liveId)
          .maybeSingle();
      if (row == null) return null;

      final map = Map<String, dynamic>.from(row);
      final profile = _readEmbeddedProfile(map['User']);
      final coverPath = map['cover_path'] as String?;
      final paths = <String?>[
        if (includeCover) coverPath,
        map['video_path'] as String?,
        profile?['avatar_path'] as String?,
      ];
      final signed = await StorageMediaUrlResolver.resolveMany(
        paths,
        client: client,
      );

      return LiveStreamDetail(
        id: map['id'] as String,
        description: map['description'] as String?,
        coverUrl: includeCover
            ? StorageMediaUrlResolver.pickNullable(signed, coverPath)
            : null,
        videoUrl: StorageMediaUrlResolver.pickNullable(
          signed,
          map['video_path'] as String?,
        ),
        streamerId: map['streamer_id'] as String?,
        streamerName: profile?['display_name'] as String?,
        streamerEmail: profile?['email'] as String?,
        streamerAvatarUrl: StorageMediaUrlResolver.pickNullable(
          signed,
          profile?['avatar_path'] as String?,
        ),
        viewerCount: map['viewer_count'] as int? ?? 0,
        isLive: map['is_live'] as bool? ?? true,
        tags: _readTags(map['tags']),
        categorySlug: map['category_slug'] as String?,
        categoryName: map['category_name'] as String?,
      );
    } catch (error, stack) {
      debugPrint('[LiveRepository] fetchRoomDetail: $error');
      debugPrint('$stack');
      return null;
    }
  }

  static List<String> _readTags(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item != null) item.toString().trim(),
      ].where((t) => t.isNotEmpty).toList();
    }
    return const [];
  }

  Map<String, dynamic>? _readEmbeddedProfile(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }
}
