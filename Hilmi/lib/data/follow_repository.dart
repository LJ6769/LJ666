import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';

class FollowToggleResult {
  const FollowToggleResult({
    required this.isFollowing,
    required this.followingIds,
  });

  final bool isFollowing;
  final List<String> followingIds;
}

/// 关注关系（public."User".following_ids + RPC toggle_follow）。
class FollowRepository {
  const FollowRepository();

  Future<FollowToggleResult?> toggleFollow(String targetUserId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    try {
      final raw = await client.rpc(
        'toggle_follow',
        params: {'p_target_id': targetUserId},
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      return FollowToggleResult(
        isFollowing: map['following'] as bool? ?? false,
        followingIds: _readUuidList(map['following_ids']),
      );
    } catch (error, stack) {
      debugPrint('[FollowRepository] toggleFollow: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<List<String>> fetchMyFollowerIds() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final user = client.auth.currentUser;
      if (user == null) return const [];

      final row = await client
          .from(SupabaseTables.user)
          .select('follower_ids')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (row == null) return const [];
      return _readUuidList(row['follower_ids']);
    } catch (error, stack) {
      debugPrint('[FollowRepository] fetchMyFollowerIds: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  Future<List<String>> fetchMyFollowingIds() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final user = client.auth.currentUser;
      if (user == null) return const [];

      final row = await client
          .from(SupabaseTables.user)
          .select('following_ids')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (row == null) return const [];
      return _readUuidList(row['following_ids']);
    } catch (error, stack) {
      debugPrint('[FollowRepository] fetchMyFollowingIds: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  Future<List<FollowUser>> fetchUsersByIds(List<String> userIds) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null || userIds.isEmpty) {
      return const [];
    }

    try {
      final rows = await client
          .from(SupabaseTables.user)
          .select('id, display_name, email, avatar_path')
          .inFilter('id', userIds) as List<dynamic>;

      final byId = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id != null && id.isNotEmpty) byId[id] = map;
      }

      final avatarPaths = byId.values
          .map((m) => m['avatar_path'] as String?)
          .where((p) => p != null && p.isNotEmpty)
          .cast<String>()
          .toList();

      final signed = avatarPaths.isEmpty
          ? const <String, String>{}
          : await StorageMediaUrlResolver.resolveMany(
              avatarPaths,
              client: client,
            );

      final users = <FollowUser>[];
      for (final id in userIds) {
        final map = byId[id];
        if (map == null) continue;
        final avatarPath = map['avatar_path'] as String?;
        final avatarUrl = avatarPath == null
            ? null
            : StorageMediaUrlResolver.pickNullable(signed, avatarPath);
        users.add(
          FollowUser(
            id: id,
            displayName: map['display_name'] as String? ?? 'Player',
            email: map['email'] as String?,
            avatarPath: avatarPath,
            avatarUrl: avatarUrl,
          ),
        );
      }
      return users;
    } catch (error, stack) {
      debugPrint('[FollowRepository] fetchUsersByIds: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  static List<String> _readUuidList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.startsWith('{') && raw.endsWith('}')) {
      final inner = raw.substring(1, raw.length - 1).trim();
      if (inner.isEmpty) return const [];
      return inner
          .split(',')
          .map((e) => e.trim())
          .where((id) => id.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
