import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/utils/storage_user_folder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 删号前通过 Storage API 清理 media 桶内用户文件（不可直接 DELETE storage.objects）。
abstract final class UserStorageCleanup {
  static const _removeBatchSize = 100;

  static Future<void> purgeAllForCurrentUser(SupabaseClient client) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) return;

    final row = await client
        .from(SupabaseTables.user)
        .select('id, email, avatar_path')
        .eq('auth_user_id', authUser.id)
        .maybeSingle();
    if (row == null) return;

    final profileId = row['id'] as String?;
    final email = row['email'] as String? ?? authUser.email ?? '';
    final avatarPath = row['avatar_path'] as String?;

    final paths = <String>{};

    if (avatarPath != null && avatarPath.trim().isNotEmpty) {
      paths.add(avatarPath.trim());
    }

    final emailFolder = StorageUserFolder.fromEmail(email);
    if (emailFolder.isNotEmpty && emailFolder != 'unknown') {
      paths.addAll(await _listAllObjectPaths(client, 'users/$emailFolder'));
    }

    paths.addAll(await _listAllObjectPaths(client, 'users/${authUser.id}'));

    if (profileId != null && profileId.isNotEmpty) {
      paths.addAll(
        await _listAllObjectPaths(client, 'moments/posts/$profileId'),
      );
      paths.addAll(await _collectPathsFromPosts(client, profileId));
      paths.addAll(await _collectPathsFromLive(client, profileId));
    }

    await _removePaths(client, paths);
  }

  static Future<Set<String>> _collectPathsFromPosts(
    SupabaseClient client,
    String profileId,
  ) async {
    final paths = <String>{};
    try {
      final rows = await client
          .from(SupabaseTables.post)
          .select('media')
          .eq('author_id', profileId) as List<dynamic>;

      for (final row in rows) {
        final media = row['media'];
        if (media is! List) continue;
        for (final item in media) {
          if (item is! Map) continue;
          _addPath(paths, item['storage_path']);
          _addPath(paths, item['poster_path']);
        }
      }
    } catch (error, stack) {
      debugPrint('[UserStorageCleanup] posts: $error');
      debugPrint('$stack');
    }
    return paths;
  }

  static Future<Set<String>> _collectPathsFromLive(
    SupabaseClient client,
    String profileId,
  ) async {
    final paths = <String>{};
    try {
      final rows = await client
          .from(SupabaseTables.live)
          .select('cover_path, video_path')
          .eq('streamer_id', profileId) as List<dynamic>;

      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        _addPath(paths, map['cover_path']);
        _addPath(paths, map['video_path']);
      }
    } catch (error, stack) {
      debugPrint('[UserStorageCleanup] live: $error');
      debugPrint('$stack');
    }
    return paths;
  }

  static void _addPath(Set<String> paths, dynamic raw) {
    if (raw is! String) return;
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) paths.add(trimmed);
  }

  static Future<List<String>> _listAllObjectPaths(
    SupabaseClient client,
    String prefix,
  ) async {
    final bucket = client.storage.from(SupabaseConfig.mediaBucket);
    final paths = <String>[];
    try {
      await _walkPrefix(bucket, prefix, paths);
    } catch (error, stack) {
      debugPrint('[UserStorageCleanup] list $prefix: $error');
      debugPrint('$stack');
    }
    return paths;
  }

  static Future<void> _walkPrefix(
    StorageFileApi bucket,
    String prefix,
    List<String> out,
  ) async {
    final items = await bucket.list(path: prefix);
    for (final item in items) {
      final name = item.name;
      if (name.isEmpty) continue;
      final fullPath = '$prefix/$name';
      if (item.id == null) {
        await _walkPrefix(bucket, fullPath, out);
      } else {
        out.add(fullPath);
      }
    }
  }

  static Future<void> _removePaths(
    SupabaseClient client,
    Set<String> paths,
  ) async {
    if (paths.isEmpty) return;

    final bucket = client.storage.from(SupabaseConfig.mediaBucket);
    final list = paths.toList(growable: false);

    for (var i = 0; i < list.length; i += _removeBatchSize) {
      final end = (i + _removeBatchSize > list.length)
          ? list.length
          : i + _removeBatchSize;
      final batch = list.sublist(i, end);
      try {
        await bucket.remove(batch);
      } catch (error, stack) {
        debugPrint('[UserStorageCleanup] remove batch failed: $error');
        debugPrint('$stack');
        rethrow;
      }
    }
  }
}
