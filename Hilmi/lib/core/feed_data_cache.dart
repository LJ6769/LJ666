// 首页与 Circle 数据内存缓存，减少 Tab 切换重复请求。
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/message_conversation.dart';

/// 朋友圈 Followed Tab 缓存（按用户 + 关注列表快照）。
class CircleFollowedPostsCache {
  const CircleFollowedPostsCache({
    required this.posts,
    required this.followedIds,
  });

  final List<CirclePost> posts;
  final Set<String> followedIds;
}

/// 个人中心帖子列表缓存（My Post + My Like）。
class ProfilePostsCache {
  const ProfilePostsCache({
    required this.myPosts,
    required this.likedPosts,
  });

  final List<CirclePost> myPosts;
  final List<CirclePost> likedPosts;
}

/// 内存缓存首页 / Circle / 个人中心数据，减少 Tab 切换与短时返回时的重复请求与签名。
abstract final class FeedDataCache {
  FeedDataCache._();

  static Duration get _ttl => SupabaseEgressConfig.feedCacheTtl;

  static HomeFeedData? _homeFeed;
  static DateTime? _homeFeedAt;

  static List<CirclePost>? _circlePosts;
  static DateTime? _circlePostsAt;

  static List<CirclePost>? _circlePopularPosts;
  static DateTime? _circlePopularPostsAt;

  static final Map<String, CircleFollowedPostsCache> _circleFollowedByUser = {};
  static final Map<String, DateTime> _circleFollowedAtByUser = {};

  static List<LiveRoom>? _bartendingLivePool;
  static Map<String, List<LiveRoom>>? _bartendingLiveByCategory;
  static DateTime? _bartendingLivePoolAt;

  static List<TipsyBarRoom>? _tipsyBarPool;
  static DateTime? _tipsyBarPoolAt;

  static List<ProfileStory>? _discoverStoryPool;
  static DateTime? _discoverStoryPoolAt;

  static List<MessageFeaturedUser>? _messageFeaturedPool;
  static DateTime? _messageFeaturedPoolAt;

  static final Map<String, ProfilePostsCache> _profilePostsByUser = {};
  static final Map<String, DateTime> _profilePostsAtByUser = {};

  static bool _isFresh(DateTime? at, {Duration? ttl}) {
    if (at == null) return false;
    return DateTime.now().difference(at) < (ttl ?? _ttl);
  }

  static HomeFeedData? get homeFeed =>
      _isFresh(_homeFeedAt) ? _homeFeed : null;

  static void setHomeFeed(HomeFeedData data) {
    _homeFeed = data;
    _homeFeedAt = DateTime.now();
  }

  static void clearHomeFeed() {
    _homeFeed = null;
    _homeFeedAt = null;
  }

  static List<CirclePost>? get circlePosts => _isFresh(
        _circlePostsAt,
        ttl: SupabaseEgressConfig.circleCacheTtl,
      )
          ? _circlePosts
          : null;

  static void setCirclePosts(List<CirclePost> posts) {
    _circlePosts = List.unmodifiable(posts);
    _circlePostsAt = DateTime.now();
  }

  static List<CirclePost>? get circlePopularPosts => _isFresh(
        _circlePopularPostsAt,
        ttl: SupabaseEgressConfig.circleCacheTtl,
      )
          ? _circlePopularPosts
          : null;

  static void setCirclePopularPosts(List<CirclePost> posts) {
    _circlePopularPosts = List.unmodifiable(posts);
    _circlePopularPostsAt = DateTime.now();
  }

  static void clearCirclePopularPosts() {
    _circlePopularPosts = null;
    _circlePopularPostsAt = null;
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final id in a) {
      if (!b.contains(id)) return false;
    }
    return true;
  }

  static List<CirclePost>? circleFollowedPosts(
    String userId,
    Set<String> followedIds,
  ) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    if (!_isFresh(
      _circleFollowedAtByUser[id],
      ttl: SupabaseEgressConfig.circleCacheTtl,
    )) {
      return null;
    }
    final entry = _circleFollowedByUser[id];
    if (entry == null) return null;
    if (!_setEquals(entry.followedIds, followedIds)) return null;
    return entry.posts;
  }

  static void setCircleFollowedPosts(
    String userId, {
    required List<CirclePost> posts,
    required Set<String> followedIds,
  }) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _circleFollowedByUser[id] = CircleFollowedPostsCache(
      posts: List.unmodifiable(posts),
      followedIds: Set.unmodifiable(followedIds),
    );
    _circleFollowedAtByUser[id] = DateTime.now();
  }

  static void invalidateCircleFollowedPosts([String? userId]) {
    if (userId == null) {
      _circleFollowedByUser.clear();
      _circleFollowedAtByUser.clear();
      return;
    }
    final id = userId.trim();
    _circleFollowedByUser.remove(id);
    _circleFollowedAtByUser.remove(id);
  }

  static void clearCirclePosts() {
    _circlePosts = null;
    _circlePostsAt = null;
    clearCirclePopularPosts();
    invalidateCircleFollowedPosts();
  }

  static List<LiveRoom>? get bartendingLivePool =>
      _isFresh(_bartendingLivePoolAt) ? _bartendingLivePool : null;

  static List<LiveRoom>? bartendingLiveCategory(String categorySlug) {
    if (!_isFresh(_bartendingLivePoolAt)) return null;
    return _bartendingLiveByCategory?[categorySlug];
  }

  static void setBartendingLivePool(List<LiveRoom> rooms) {
    _bartendingLivePool = List.unmodifiable(rooms);
    _bartendingLiveByCategory = _groupBartendingByCategory(rooms);
    _bartendingLivePoolAt = DateTime.now();
  }

  static Map<String, List<LiveRoom>> _groupBartendingByCategory(
    List<LiveRoom> rooms,
  ) {
    final grouped = <String, List<LiveRoom>>{};
    for (final room in rooms) {
      final slug = room.categorySlug?.trim().toLowerCase();
      if (slug == null || slug.isEmpty) continue;
      grouped.putIfAbsent(slug, () => <LiveRoom>[]).add(room);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable(entry.value),
    };
  }

  static void clearBartendingLivePool() {
    _bartendingLivePool = null;
    _bartendingLiveByCategory = null;
    _bartendingLivePoolAt = null;
  }

  static List<TipsyBarRoom>? get tipsyBarPool =>
      _isFresh(_tipsyBarPoolAt) ? _tipsyBarPool : null;

  static void setTipsyBarPool(List<TipsyBarRoom> rooms) {
    _tipsyBarPool = List.unmodifiable(rooms);
    _tipsyBarPoolAt = DateTime.now();
  }

  static void invalidateTipsyBarPool() {
    _tipsyBarPool = null;
    _tipsyBarPoolAt = null;
  }

  static List<ProfileStory>? get discoverStoryPool =>
      _isFresh(_discoverStoryPoolAt) ? _discoverStoryPool : null;

  static void setDiscoverStoryPool(List<ProfileStory> stories) {
    _discoverStoryPool = List.unmodifiable(stories);
    _discoverStoryPoolAt = DateTime.now();
  }

  static void clearDiscoverStoryPool() {
    _discoverStoryPool = null;
    _discoverStoryPoolAt = null;
  }

  static List<MessageFeaturedUser>? get messageFeaturedPool =>
      _isFresh(_messageFeaturedPoolAt) ? _messageFeaturedPool : null;

  static void setMessageFeaturedPool(List<MessageFeaturedUser> users) {
    _messageFeaturedPool = List.unmodifiable(users);
    _messageFeaturedPoolAt = DateTime.now();
  }

  static void clearMessageFeaturedPool() {
    _messageFeaturedPool = null;
    _messageFeaturedPoolAt = null;
  }

  static ProfilePostsCache? profilePosts(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    if (!_isFresh(
      _profilePostsAtByUser[id],
      ttl: SupabaseEgressConfig.profilePostsCacheTtl,
    )) {
      return null;
    }
    return _profilePostsByUser[id];
  }

  static void setProfilePosts(
    String userId, {
    required List<CirclePost> myPosts,
    required List<CirclePost> likedPosts,
  }) {
    final id = userId.trim();
    if (id.isEmpty) return;
    _profilePostsByUser[id] = ProfilePostsCache(
      myPosts: List.unmodifiable(myPosts),
      likedPosts: List.unmodifiable(likedPosts),
    );
    _profilePostsAtByUser[id] = DateTime.now();
  }

  static void patchProfilePosts(
    String userId, {
    List<CirclePost>? myPosts,
    List<CirclePost>? likedPosts,
  }) {
    final id = userId.trim();
    if (id.isEmpty) return;
    final existing = _profilePostsByUser[id];
    if (existing == null && myPosts == null && likedPosts == null) return;
    setProfilePosts(
      id,
      myPosts: myPosts ?? existing?.myPosts ?? const [],
      likedPosts: likedPosts ?? existing?.likedPosts ?? const [],
    );
  }

  static void clearProfilePosts([String? userId]) {
    if (userId == null) {
      _profilePostsByUser.clear();
      _profilePostsAtByUser.clear();
      return;
    }
    final id = userId.trim();
    _profilePostsByUser.remove(id);
    _profilePostsAtByUser.remove(id);
  }

  static void clearAll() {
    clearHomeFeed();
    clearCirclePosts();
    clearBartendingLivePool();
    invalidateTipsyBarPool();
    clearDiscoverStoryPool();
    clearMessageFeaturedPool();
    clearProfilePosts();
  }

  static void invalidateHomeFeed() => clearHomeFeed();

  /// 媒体路径解析策略变更后调用，避免旧缓存无图。
  static void invalidateCirclePosts() => clearCirclePosts();
}
