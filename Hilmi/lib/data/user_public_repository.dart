// 任意用户公开资料查询（个人中心/明星页）。
import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/star_public_profile.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 公开用户资料（个人中心）。
class UserPublicRepository {
  const UserPublicRepository();

  Future<StarPublicProfile?> fetchProfile(String userId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    try {
      final row = await client
          .from(SupabaseTables.user)
          .select('id, display_name, email, avatar_path, bio')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;

      final avatarPath = row['avatar_path'] as String?;
      final avatarUrl = avatarPath != null && avatarPath.isNotEmpty
          ? await StorageMediaUrlResolver.resolve(avatarPath, client: client)
          : null;

      final featured = await _fetchLatestPostPreview(userId, client);

      return StarPublicProfile(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? row['display_name'] as String
            : 'User',
        email: row['email'] as String?,
        bio: row['bio'] as String?,
        avatarUrl: avatarUrl?.isNotEmpty == true ? avatarUrl : null,
        avatarPath: avatarPath,
        featuredImageUrl: featured?.$1,
        featuredImageCacheKey: featured?.$2,
      );
    } catch (error, stack) {
      debugPrint('[UserPublicRepository] fetchProfile: $error');
      debugPrint('$stack');
      return null;
    }
  }

  static Future<(String?, String?)?> _fetchLatestPostPreview(
    String userId,
    SupabaseClient client,
  ) async {
    try {
      final post = await client
          .from(SupabaseTables.post)
          .select('media')
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (post == null) return null;

      final media = post['media'] as List<dynamic>? ?? [];
      if (media.isEmpty) return null;

      final sorted = [...media]
        ..sort((a, b) {
          final ao = (a as Map<String, dynamic>)['sort_order'] as int? ?? 0;
          final bo = (b as Map<String, dynamic>)['sort_order'] as int? ?? 0;
          return ao.compareTo(bo);
        });

      for (final item in sorted) {
        final map = item as Map<String, dynamic>;
        final type = map['type'] as String? ?? 'image';
        final path = map['storage_path'] as String?;
        final posterPath = map['poster_path'] as String?;
        final displayPath = type == 'video' ? posterPath : path;
        if (displayPath == null || displayPath.isEmpty) continue;

        final url = await StorageMediaUrlResolver.resolve(
          displayPath,
          client: client,
        );
        if (url.isNotEmpty) return (url, displayPath);
      }
      return null;
    } catch (error, stack) {
      debugPrint('[UserPublicRepository] latest post: $error');
      debugPrint('$stack');
      return null;
    }
  }
}
