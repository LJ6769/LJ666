import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/models/live_viewer.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';

/// 观众列表数据（从 User 表抽样，排除主播）。
class LiveViewersRepository {
  const LiveViewersRepository();

  /// 随机抽取 [minCount]～[maxCount] 名观众（含种子用户）。
  Future<List<LiveViewer>> fetchRandomViewers({
    int minCount = 5,
    int maxCount = FeedConfig.liveViewersDefaultLimit,
    Iterable<String> excludeUserIds = const [],
  }) {
    final min = minCount.clamp(1, maxCount);
    final max = maxCount.clamp(min, 99);
    final limit = min + Random().nextInt(max - min + 1);
    return fetchViewers(
      limit: limit,
      excludeUserIds: excludeUserIds,
    );
  }

  Future<List<LiveViewer>> fetchViewers({
    int limit = FeedConfig.liveViewersDefaultLimit,
    String? excludeUserId,
    Iterable<String> excludeUserIds = const [],
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.user)
          .select('id, display_name, avatar_path')
          .limit(60) as List<dynamic>;

      final candidates = <Map<String, dynamic>>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id == null || id.isEmpty) continue;
        if (excludeUserId != null && id == excludeUserId) continue;
        if (excludeUserIds.contains(id)) continue;
        final name = (map['display_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        candidates.add(map);
      }

      if (candidates.isEmpty) return const [];

      candidates.shuffle(Random());
      final picked = candidates.take(limit).toList();

      final viewers = <LiveViewer>[];
      for (final map in picked) {
        final avatarPath = map['avatar_path'] as String?;
        String? avatarUrl;
        if (avatarPath != null && avatarPath.isNotEmpty) {
          final resolved =
              await StorageMediaUrlResolver.resolve(avatarPath, client: client);
          if (resolved.isNotEmpty) avatarUrl = resolved;
        }
        viewers.add(
          LiveViewer(
            id: map['id'] as String,
            displayName: map['display_name'] as String,
            avatarUrl: avatarUrl,
          ),
        );
      }
      return viewers;
    } catch (error, stack) {
      debugPrint('[LiveViewersRepository] fetchViewers: $error');
      debugPrint('$stack');
      return const [];
    }
  }
}
