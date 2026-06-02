/// 首页 / 朋友圈 / 消息等列表拉取与展示数量。
abstract final class FeedConfig {
  // —— 朋友圈 Circle ——
  static const int circlePoolLimit = 24;
  static const int circleMaxFetchLimit = 96;
  static const int circleDisplayCount = 8;

  // —— Discover 首页 ——
  static const int discoverPreviewCount = 6;
  static const int discoverPoolLimit = 48;
  static const int liveHomePreviewCount = 3;
  static const int livePopularListCount = 4;
  static const int tipsyBarHomePreviewCount = 3;

  // —— 消息 Tab 推荐用户 ——
  static const int messageFeaturedPoolLimit = 48;
  static const int messageFeaturedDisplayCount = 6;

  // —— 直播间观众列表 ——
  static const int liveViewersDefaultLimit = 8;
}
