// 未登录观众随机身份（从 User 表抽样，会话内固定）。
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';

/// 当前观众身份（无登录时从 User 表随机一名，会话内保持不变）。
class ViewerProfile {
  const ViewerProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
}

abstract final class ViewerSession {
  static ViewerProfile? _cached;

  static ViewerProfile? get current => _cached;

  static void reset() => _cached = null;

  /// 加载并缓存一名观众；可排除主播 id。
  static Future<ViewerProfile?> ensureLoaded({String? excludeUserId}) async {
    if (_cached != null) {
      if (excludeUserId == null || _cached!.id != excludeUserId) {
        return _cached;
      }
    }

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    try {
      final rows = await client
          .from(SupabaseTables.user)
          .select('id, display_name, avatar_path')
          .limit(40) as List<dynamic>;

      final candidates = <Map<String, dynamic>>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id == null || id.isEmpty) continue;
        if (excludeUserId != null && id == excludeUserId) continue;
        final name = (map['display_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        candidates.add(map);
      }

      if (candidates.isEmpty) return _cached;

      final pick = candidates[Random().nextInt(candidates.length)];
      final avatarPath = pick['avatar_path'] as String?;
      String? avatarUrl;
      if (avatarPath != null && avatarPath.isNotEmpty) {
        final resolved =
            await StorageMediaUrlResolver.resolve(avatarPath, client: client);
        if (resolved.isNotEmpty) avatarUrl = resolved;
      }

      _cached = ViewerProfile(
        id: pick['id'] as String,
        displayName: pick['display_name'] as String,
        avatarUrl: avatarUrl,
      );
      return _cached;
    } catch (error, stack) {
      debugPrint('[ViewerSession] ensureLoaded: $error');
      debugPrint('$stack');
      return _cached;
    }
  }
}
