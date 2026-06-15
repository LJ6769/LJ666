// 当前用户点赞帖子 ID 列表，与 liked_post_ids 同步。
import 'package:flutter/foundation.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/data/like_repository.dart';
import 'package:hilmi/models/user_profile.dart';

/// 当前用户点赞列表（与 Supabase liked_post_ids 同步）。
abstract final class LikeService {
  static const _repository = LikeRepository();

  static final likedPostIds = ValueNotifier<Set<String>>(<String>{});

  static bool isLiked(String postId) => likedPostIds.value.contains(postId);

  static void reset() {
    likedPostIds.value = <String>{};
  }

  static void applyFromProfile(UserProfile? profile) {
    if (profile == null) {
      reset();
      return;
    }
    final next = profile.likedPostIds.toSet();
    if (_setEquals(likedPostIds.value, next)) return;
    likedPostIds.value = next;
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final id in a) {
      if (!b.contains(id)) return false;
    }
    return true;
  }

  /// 切换点赞；返回切换后是否已点赞。
  static Future<bool> toggle(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(postId, 'postId', 'must not be empty');
    }

    final previous = Set<String>.from(likedPostIds.value);
    final optimistic = Set<String>.from(previous);
    if (optimistic.contains(id)) {
      optimistic.remove(id);
    } else {
      optimistic.add(id);
    }
    likedPostIds.value = optimistic;
    AuthService.patchLikedPostIds(optimistic.toList());

    try {
      final result = await _repository.togglePostLike(id);
      if (result == null) {
        likedPostIds.value = previous;
        AuthService.patchLikedPostIds(previous.toList());
        throw StateError('Like update failed.');
      }
      likedPostIds.value = result.likedPostIds.toSet();
      AuthService.patchLikedPostIds(result.likedPostIds);
      return result.isLiked;
    } catch (error) {
      likedPostIds.value = previous;
      AuthService.patchLikedPostIds(previous.toList());
      rethrow;
    }
  }
}
