import 'package:flutter/foundation.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/data/block_repository.dart';
import 'package:hilmi/data/follow_repository.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/user_profile.dart';

/// 当前用户黑名单（与 Supabase blocked_ids 同步）。
abstract final class BlockService {
  static const _repository = BlockRepository();
  static const _followRepository = FollowRepository();

  static final blockedIds = ValueNotifier<Set<String>>(<String>{});

  static bool isBlocked(String? userId) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) return false;
    return blockedIds.value.contains(id);
  }

  static void reset() {
    blockedIds.value = <String>{};
  }

  static void applyFromProfile(UserProfile? profile) {
    if (profile == null) {
      reset();
      return;
    }
    blockedIds.value = profile.blockedIds.toSet();
  }

  static Future<void> refreshFromServer() async {
    if (!AuthService.isLoggedIn) {
      reset();
      return;
    }
    final ids = await _repository.fetchMyBlockedIds();
    blockedIds.value = ids.toSet();
  }

  /// 拉黑；返回是否已在黑名单。
  static Future<bool> block(String targetUserId) async {
    if (isBlocked(targetUserId)) return true;
    return toggle(targetUserId);
  }

  /// 移出黑名单。
  static Future<bool> unblock(String targetUserId) async {
    if (!isBlocked(targetUserId)) return false;
    return toggle(targetUserId);
  }

  static Future<bool> toggle(String targetUserId) async {
    final result = await _repository.toggleBlock(targetUserId);
    if (result == null) {
      throw StateError('Block update failed.');
    }
    blockedIds.value = result.blockedIds.toSet();
    FeedDataCache.invalidateCirclePosts();
    FeedDataCache.invalidateHomeFeed();
    await FollowService.refreshFromServer();
    return result.isBlocked;
  }

  static Future<List<FollowUser>> loadBlockedUsers() async {
    if (!AuthService.isLoggedIn) return const [];
    await refreshFromServer();
    final ids = blockedIds.value.toList();
    if (ids.isEmpty) return const [];
    return _followRepository.fetchUsersByIds(ids);
  }

  static List<CirclePost> filterPosts(List<CirclePost> posts) {
    if (blockedIds.value.isEmpty) return posts;
    return posts
        .where((post) => !isBlocked(post.authorId))
        .toList(growable: false);
  }

  static List<LiveRoom> filterLiveRooms(List<LiveRoom> rooms) {
    if (blockedIds.value.isEmpty) return rooms;
    return rooms
        .where((room) => !isBlocked(room.hostId))
        .toList(growable: false);
  }
}
