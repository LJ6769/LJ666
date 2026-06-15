// 朋友圈 Post 表：列表、详情、评论、删帖等。
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/models/circle_comment.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 朋友圈（Circle）数据：从 Post 表读取。
class CircleRepository {
  const CircleRepository();

  /// 从数据库拉取的候选池大小（单批；不足 8 条时会加大 limit 重试）。
  static const _postSelectQuery = '''
          id,
          content,
          author_id,
          media,
          created_at,
          User!author_id ( display_name, avatar_path, email )
        ''';

  Future<List<CirclePost>> fetchAllPosts({
    int limit = FeedConfig.circlePoolLimit,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      FeedDataCache.invalidateCirclePosts();
    } else {
      final cached = FeedDataCache.circlePosts;
      if (cached != null) {
        return cached.toList();
      }
    }

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.post)
          .select(_postSelectQuery)
          .order('created_at', ascending: false)
          .limit(limit) as List<dynamic>;

      final posts = await _mapPostList(client, rows);
      FeedDataCache.setCirclePosts(posts);
      return posts;
    } catch (error, stack) {
      debugPrint('[CircleRepository] fetchAllPosts: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  /// Popular：首次进入拉取并缓存 30 天；后续从本地读取（下拉刷新强制重拉）。
  Future<List<CirclePost>> fetchPopularPosts({
    bool forceRefresh = false,
    Set<String> blockedAuthorIds = const {},
  }) async {
    const target = FeedConfig.circleDisplayCount;

    if (forceRefresh) {
      FeedDataCache.invalidateCirclePosts();
    } else {
      final cached = FeedDataCache.circlePopularPosts;
      if (cached != null) {
        final resolved = await _resolvePopularDisplayList(
          cached,
          blockedAuthorIds: blockedAuthorIds,
          target: target,
        );
        if (resolved.isNotEmpty) {
          FeedDataCache.setCirclePopularPosts(resolved);
        }
        if (resolved.length >= target) return resolved;
      }
    }
    var queryLimit = FeedConfig.circlePoolLimit;
    var refresh = forceRefresh;

    while (true) {
      final pool = await fetchAllPosts(limit: queryLimit, forceRefresh: refresh);
      refresh = false;

      final eligible = _filterBlockedAuthors(pool, blockedAuthorIds);

      final hasMoreInDb = pool.length >= queryLimit;
      if (eligible.length >= target || !hasMoreInDb) {
        final result = _pickRandomPosts(eligible, target);
        if (result.isNotEmpty) {
          FeedDataCache.setCirclePopularPosts(result);
        }
        return result;
      }

      if (queryLimit >= FeedConfig.circleMaxFetchLimit) {
        final result = _pickRandomPosts(eligible, target);
        if (result.isNotEmpty) {
          FeedDataCache.setCirclePopularPosts(result);
        }
        return result;
      }

      queryLimit += FeedConfig.circlePoolLimit;
      FeedDataCache.invalidateCirclePosts();
    }
  }

  List<CirclePost> _filterBlockedAuthors(
    List<CirclePost> posts,
    Set<String> blockedAuthorIds,
  ) {
    if (blockedAuthorIds.isEmpty) return posts;
    return posts
        .where((post) => !blockedAuthorIds.contains(post.authorId))
        .toList(growable: false);
  }

  Future<List<CirclePost>> _resolvePopularDisplayList(
    List<CirclePost> current,
    {
    required Set<String> blockedAuthorIds,
    required int target,
  }) async {
    final kept = _filterBlockedAuthors(current, blockedAuthorIds);
    if (kept.length >= target) {
      return kept.take(target).toList(growable: false);
    }
    return _refillPopularFromPool(
      kept,
      blockedAuthorIds: blockedAuthorIds,
      target: target,
    );
  }

  Future<List<CirclePost>> _refillPopularFromPool(
    List<CirclePost> kept, {
    required Set<String> blockedAuthorIds,
    required int target,
  }) async {
    final keptIds = kept.map((post) => post.id).toSet();
    var pool = FeedDataCache.circlePosts;
    if (pool == null || pool.isEmpty) {
      pool = await fetchAllPosts(limit: FeedConfig.circlePoolLimit);
    }

    final candidates = _filterBlockedAuthors(pool, blockedAuthorIds)
        .where((post) => !keptIds.contains(post.id))
        .toList(growable: false);
    final result = List<CirclePost>.from(kept);
    if (result.length < target && candidates.isNotEmpty) {
      final shuffled = List<CirclePost>.from(candidates)..shuffle(Random());
      for (final post in shuffled) {
        if (result.length >= target) break;
        result.add(post);
      }
    }
    return result;
  }

  List<CirclePost> _pickRandomPosts(List<CirclePost> eligible, int target) {
    if (eligible.isEmpty) return eligible;
    final shuffled = List<CirclePost>.from(eligible)..shuffle(Random());
    return shuffled.length <= target
        ? shuffled
        : shuffled.take(target).toList();
  }

  /// Followed：首次拉取并缓存 30 天；后续从本地读取（下拉刷新强制重拉）。
  Future<List<CirclePost>> fetchFollowedPosts({
    required String userId,
    required Set<String> followedAuthorIds,
    Set<String> blockedAuthorIds = const {},
    bool forceRefresh = false,
    int limit = FeedConfig.circleDisplayCount,
  }) async {
    if (followedAuthorIds.isEmpty) return const [];

    final cacheUserId = userId.trim();
    if (forceRefresh) {
      FeedDataCache.invalidateCircleFollowedPosts(cacheUserId);
    } else if (cacheUserId.isNotEmpty) {
      final cached = FeedDataCache.circleFollowedPosts(
        cacheUserId,
        followedAuthorIds,
      );
      if (cached != null) {
        return _filterBlockedAuthors(cached, blockedAuthorIds);
      }
    }

    final eligibleIds = followedAuthorIds
        .where((id) => !blockedAuthorIds.contains(id))
        .toList(growable: false);
    if (eligibleIds.isEmpty) return const [];

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.post)
          .select(_postSelectQuery)
          .inFilter('author_id', eligibleIds)
          .order('created_at', ascending: false)
          .limit(limit) as List<dynamic>;
      final posts = await _mapPostList(client, rows);
      if (cacheUserId.isNotEmpty) {
        FeedDataCache.setCircleFollowedPosts(
          cacheUserId,
          posts: posts,
          followedIds: followedAuthorIds,
        );
      }
      return posts;
    } catch (error, stack) {
      debugPrint('[CircleRepository] fetchFollowedPosts: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  /// 当前用户发布的帖子（个人中心 My Post）。
  Future<List<CirclePost>> fetchPostsByAuthorId(
    String authorId, {
    int limit = 50,
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];
    final id = authorId.trim();
    if (id.isEmpty) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.post)
          .select(_postSelectQuery)
          .eq('author_id', id)
          .order('created_at', ascending: false)
          .limit(limit) as List<dynamic>;
      return _mapPostList(client, rows);
    } catch (error, stack) {
      debugPrint('[CircleRepository] fetchPostsByAuthorId: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  /// 按 id 列表拉取帖子（个人中心 My Like，顺序与 [postIds] 一致）。
  Future<List<CirclePost>> fetchPostsByIds(List<String> postIds) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    final ids = postIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.post)
          .select(_postSelectQuery)
          .inFilter('id', ids) as List<dynamic>;

      final posts = await _mapPostList(client, rows);
      final byId = {for (final p in posts) p.id: p};
      return [
        for (final id in ids)
          if (byId.containsKey(id)) byId[id]!,
      ];
    } catch (error, stack) {
      debugPrint('[CircleRepository] fetchPostsByIds: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  Future<List<CirclePost>> _mapPostList(
    SupabaseClient client,
    List<dynamic> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final signed = await _signedUrlsForPostRows(client, rows);
    return rows
        .map((row) => _mapPostRow(row as Map<String, dynamic>, signed))
        .where((post) => post.media.isNotEmpty)
        .toList();
  }

  Future<Map<String, String>> _signedUrlsForPostRows(
    SupabaseClient client,
    List<dynamic> rows,
  ) async {
    final mediaPaths = <String?>[];
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      mediaPaths.add(
        _readEmbeddedProfile(map['User'])?['avatar_path'] as String?,
      );
      mediaPaths.addAll(
        StorageMediaUrlResolver.displayPathsForPostMedia(
          map['media'] as List<dynamic>?,
        ),
      );
    }
    return StorageMediaUrlResolver.resolveMany(mediaPaths, client: client);
  }

  CirclePost _mapPostRow(
    Map<String, dynamic> map,
    Map<String, String> signed,
  ) {
    final mediaRows = map['media'] as List<dynamic>? ?? [];
    final sortedRows = [...mediaRows]
      ..sort((a, b) {
        final aOrder = (a as Map<String, dynamic>)['sort_order'] as int? ?? 0;
        final bOrder = (b as Map<String, dynamic>)['sort_order'] as int? ?? 0;
        return aOrder.compareTo(bOrder);
      });

    final profile = _readEmbeddedProfile(map['User']);
    final media = sortedRows
        .map((m) {
          final mm = m as Map<String, dynamic>;
          final type = mm['type'] as String? ?? 'image';
          final path = mm['storage_path'] as String?;
          final posterPath = mm['poster_path'] as String?;
          final isVideo = type == 'video';
          final displayPath = isVideo ? posterPath : path;
          final displayUrl = StorageMediaUrlResolver.pick(signed, displayPath);
          final posterUrl =
              StorageMediaUrlResolver.pickNullable(signed, posterPath);
          return CircleMedia(
            type: type,
            url: isVideo ? '' : displayUrl,
            posterUrl: posterUrl,
            displayPath: displayPath,
            videoPath: isVideo ? path : null,
          );
        })
        .where((m) => m.isVideo || m.previewUrl.isNotEmpty)
        .toList();

    final rawContent = map['content'] as String? ?? '';
    return CirclePost(
      id: map['id'] as String,
      content: rawContent.trim(),
      authorId: map['author_id'] as String? ?? '',
      authorName: profile?['display_name'] as String? ?? 'Unknown',
      authorEmail: profile?['email'] as String?,
      authorAvatarUrl: StorageMediaUrlResolver.pickNullable(
        signed,
        profile?['avatar_path'] as String?,
      ),
      authorAvatarPath: profile?['avatar_path'] as String?,
      media: media,
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  static const _commentSelectQuery = '''
          id,
          post_id,
          content,
          created_at,
          author_id,
          User!author_id ( display_name, avatar_path, email )
        ''';

  Future<List<CircleComment>> fetchComments(String postId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.postChat)
          .select(_commentSelectQuery)
          .eq('post_id', postId)
          .order('created_at', ascending: true) as List<dynamic>;

      if (rows.isEmpty) return const [];

      final avatarPaths = <String?>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        avatarPaths.add(
          _readEmbeddedProfile(map['User'])?['avatar_path'] as String?,
        );
      }
      final signed =
          await StorageMediaUrlResolver.resolveMany(avatarPaths, client: client);

      return rows.map((row) {
        final map = row as Map<String, dynamic>;
        final profile = _readEmbeddedProfile(map['User']);
        final avatarPath = profile?['avatar_path'] as String?;
        return CircleComment(
          id: map['id'] as String,
          postId: map['post_id'] as String? ?? postId,
          authorId: map['author_id'] as String? ?? '',
          authorName: profile?['display_name'] as String? ?? 'Unknown',
          authorEmail: profile?['email'] as String?,
          authorAvatarUrl: StorageMediaUrlResolver.pickNullable(
            signed,
            avatarPath,
          ),
          authorAvatarPath: avatarPath,
          content: (map['content'] as String? ?? '').trim(),
          createdAt: _parseDateTime(map['created_at']),
        );
      }).toList();
    } catch (error, stack) {
      debugPrint('[CircleRepository] fetchComments: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  /// 发表评论（需已登录）。
  Future<CircleComment> sendComment({
    required String postId,
    required String content,
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not ready');
    }

    var profile = AuthService.cachedProfile;
    if (AuthService.isLoggedIn && profile == null) {
      profile = await AuthService.loadCurrentProfile();
    }
    if (profile == null) {
      throw StateError('Not signed in');
    }
    final authorId = profile.id.trim();
    if (authorId.isEmpty) {
      throw StateError('Not signed in');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Comment cannot be empty');
    }

    final row = await client
        .from(SupabaseTables.postChat)
        .insert({
          'post_id': postId,
          'author_id': authorId,
          'content': trimmed,
        })
        .select(_commentSelectQuery)
        .single();

    final map = Map<String, dynamic>.from(row);
    final embedded = _readEmbeddedProfile(map['User']);
    final avatarPath = embedded?['avatar_path'] as String? ?? profile.avatarPath;
    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final resolved =
          await StorageMediaUrlResolver.resolve(avatarPath, client: client);
      if (resolved.isNotEmpty) avatarUrl = resolved;
    }
    avatarUrl ??= profile.avatarUrl;

    return CircleComment(
      id: map['id'] as String,
      postId: map['post_id'] as String? ?? postId,
      authorId: authorId,
      authorName: embedded?['display_name'] as String? ?? profile.displayName,
      authorEmail: embedded?['email'] as String? ?? profile.email,
      authorAvatarUrl: avatarUrl,
      authorAvatarPath: avatarPath,
      content: trimmed,
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
    );
  }

  /// 删除当前用户发表的评论。
  Future<bool> deleteComment(String commentId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return false;

    final id = commentId.trim();
    if (id.isEmpty) return false;

    if (!AuthService.isLoggedIn) {
      throw StateError('Not signed in');
    }

    try {
      await client.rpc(
        'delete_own_post_comment',
        params: {'p_comment_id': id},
      );
      return true;
    } catch (error, stack) {
      debugPrint('[CircleRepository] deleteComment: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  /// 删除当前用户发布的帖子（含评论级联；尽力清理 Storage 媒体）。
  Future<bool> deletePost(String postId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return false;

    var profile = AuthService.cachedProfile;
    if (AuthService.isLoggedIn && profile == null) {
      profile = await AuthService.loadCurrentProfile();
    }
    final authorId = profile?.id.trim() ?? '';
    if (authorId.isEmpty) {
      throw StateError('Not signed in');
    }

    final id = postId.trim();
    if (id.isEmpty) return false;

    try {
      final row = await client
          .from(SupabaseTables.post)
          .select('id, author_id, media')
          .eq('id', id)
          .eq('author_id', authorId)
          .maybeSingle();

      if (row == null) return false;

      final mediaPaths = _storagePathsFromPostMedia(row['media']);
      await _deleteStoragePaths(client, mediaPaths);

      await client
          .from(SupabaseTables.post)
          .delete()
          .eq('id', id)
          .eq('author_id', authorId);

      if (LikeService.likedPostIds.value.contains(id)) {
        final nextLiked = LikeService.likedPostIds.value
            .where((likedId) => likedId != id)
            .toList();
        AuthService.patchLikedPostIds(nextLiked);
        LikeService.likedPostIds.value = nextLiked.toSet();
      }

      FeedDataCache.invalidateCirclePosts();
      return true;
    } catch (error, stack) {
      debugPrint('[CircleRepository] deletePost: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  static Set<String> _storagePathsFromPostMedia(Object? media) {
    final paths = <String>{};
    if (media is! List) return paths;
    for (final item in media) {
      if (item is! Map) continue;
      final storagePath = item['storage_path'];
      final posterPath = item['poster_path'];
      if (storagePath is String && storagePath.trim().isNotEmpty) {
        paths.add(storagePath.trim());
      }
      if (posterPath is String && posterPath.trim().isNotEmpty) {
        paths.add(posterPath.trim());
      }
    }
    return paths;
  }

  static Future<void> _deleteStoragePaths(
    SupabaseClient client,
    Set<String> paths,
  ) async {
    if (paths.isEmpty) return;
    try {
      await client.storage.from(SupabaseConfig.mediaBucket).remove(paths.toList());
    } catch (error, stack) {
      debugPrint('[CircleRepository] delete storage: $error');
      debugPrint('$stack');
    }
  }

  Future<String?> resolveVideoUrl(String? videoPath) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;
    final path = videoPath?.trim();
    if (path == null || path.isEmpty) return null;

    final cached = StorageMediaUrlResolver.lookup(path);
    if (cached.isNotEmpty) return cached;

    try {
      final url = await StorageMediaUrlResolver.resolve(path, client: client);
      return url.isEmpty ? null : url;
    } catch (error, stack) {
      debugPrint('[CircleRepository] resolveVideoUrl: $error');
      debugPrint('$stack');
      return null;
    }
  }

  /// 仅预热签名缓存，不下载视频（零 egress）。
  Future<void> prefetchVideoSignature(String? videoPath) async {
    await resolveVideoUrl(videoPath);
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
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
