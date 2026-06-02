import 'package:flutter/foundation.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/data/follow_repository.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/models/user_profile.dart';

/// 当前用户关注列表（与 Supabase following_ids 同步）。
abstract final class FollowService {
  static const _repository = FollowRepository();

  static final followedIds = ValueNotifier<Set<String>>(<String>{});

  static bool isFollowing(String userId) =>
      followedIds.value.contains(userId);

  static void reset() {
    followedIds.value = <String>{};
  }

  static void applyFromProfile(UserProfile? profile) {
    if (profile == null) {
      reset();
      return;
    }
    followedIds.value = profile.followingIds.toSet();
  }

  static Future<void> refreshFromServer() async {
    if (!AuthService.isLoggedIn) {
      reset();
      return;
    }
    final ids = await _repository.fetchMyFollowingIds();
    followedIds.value = ids.toSet();
  }

  /// 切换关注；返回切换后是否已关注。
  static Future<bool> toggle(String targetUserId) async {
    final result = await _repository.toggleFollow(targetUserId);
    if (result == null) {
      throw StateError('Follow update failed.');
    }
    followedIds.value = result.followingIds.toSet();
    return result.isFollowing;
  }

  static Future<List<FollowUser>> loadFollowingUsers() async {
    await refreshFromServer();
    final ids = followedIds.value.toList();
    if (ids.isEmpty) return const [];
    return _repository.fetchUsersByIds(ids);
  }

  /// 关注我的用户（设置 → Followers）。
  static Future<List<FollowUser>> loadFollowerUsers() async {
    if (!AuthService.isLoggedIn) return const [];
    await refreshFromServer();
    final ids = await _repository.fetchMyFollowerIds();
    if (ids.isEmpty) return const [];
    return _repository.fetchUsersByIds(ids);
  }
}
