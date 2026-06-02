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
    likedPostIds.value = profile.likedPostIds.toSet();
  }

  /// 切换点赞；返回切换后是否已点赞。
  static Future<bool> toggle(String postId) async {
    final result = await _repository.togglePostLike(postId);
    if (result == null) {
      throw StateError('Like update failed.');
    }
    likedPostIds.value = result.likedPostIds.toSet();
    AuthService.patchLikedPostIds(result.likedPostIds);
    return result.isLiked;
  }
}
