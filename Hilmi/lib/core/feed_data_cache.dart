import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/models/home_models.dart';

/// 内存缓存首页 / Circle 数据，减少 Tab 切换与短时返回时的重复请求与签名。
abstract final class FeedDataCache {
  FeedDataCache._();

  static Duration get _ttl => SupabaseEgressConfig.feedCacheTtl;

  static HomeFeedData? _homeFeed;
  static DateTime? _homeFeedAt;

  static List<CirclePost>? _circlePosts;
  static DateTime? _circlePostsAt;

  static bool _isFresh(DateTime? at) {
    if (at == null) return false;
    return DateTime.now().difference(at) < _ttl;
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

  static List<CirclePost>? get circlePosts =>
      _isFresh(_circlePostsAt) ? _circlePosts : null;

  static void setCirclePosts(List<CirclePost> posts) {
    _circlePosts = List.unmodifiable(posts);
    _circlePostsAt = DateTime.now();
  }

  static void clearCirclePosts() {
    _circlePosts = null;
    _circlePostsAt = null;
  }

  static void clearAll() {
    clearHomeFeed();
    clearCirclePosts();
  }

  static void invalidateHomeFeed() => clearHomeFeed();

  /// 媒体路径解析策略变更后调用，避免旧缓存无图。
  static void invalidateCirclePosts() => clearCirclePosts();
}
