import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';

class LikeToggleResult {
  const LikeToggleResult({
    required this.isLiked,
    required this.likedPostIds,
    this.likeCount,
  });

  final bool isLiked;
  final List<String> likedPostIds;
  final int? likeCount;
}

/// 朋友圈点赞（public."User".liked_post_ids + RPC toggle_post_like）。
class LikeRepository {
  const LikeRepository();

  Future<LikeToggleResult?> togglePostLike(String postId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    final id = postId.trim();
    if (id.isEmpty) return null;

    try {
      final raw = await client.rpc(
        'toggle_post_like',
        params: {'p_post_id': id},
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      return LikeToggleResult(
        isLiked: map['liked'] as bool? ?? false,
        likedPostIds: _readUuidList(map['liked_post_ids']),
        likeCount: _readInt(map['like_count']),
      );
    } catch (error, stack) {
      debugPrint('[LikeRepository] togglePostLike: $error');
      debugPrint('$stack');
      rethrow;
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
    return const [];
  }

  static int? _readInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }
}
