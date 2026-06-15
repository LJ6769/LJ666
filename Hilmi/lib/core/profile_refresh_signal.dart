// 广播通知个人中心刷新资料或帖子/点赞列表。
import 'package:flutter/foundation.dart';

/// 通知个人中心刷新；[postsOnly] 为 true 时不强制重拉资料，避免牵动朋友圈二次 reload。
class ProfileRefreshEvent {
  ProfileRefreshEvent._({required this.postsOnly, required this.id});

  final bool postsOnly;
  final int id;

  static int _seq = 0;

  factory ProfileRefreshEvent.full() =>
      ProfileRefreshEvent._(postsOnly: false, id: ++_seq);

  factory ProfileRefreshEvent.postsOnly() =>
      ProfileRefreshEvent._(postsOnly: true, id: ++_seq);
}

/// 通知个人中心重新拉取 My Post / My Like（发帖、切 Tab 等）。
abstract final class ProfileRefreshSignal {
  static final notifier = ValueNotifier<ProfileRefreshEvent>(
    ProfileRefreshEvent.full(),
  );

  static void notify() {
    notifier.value = ProfileRefreshEvent.full();
  }

  /// 发帖成功等：只更新 My Post / My Like，不 forceRefresh 全局资料。
  static void notifyPostsOnly() {
    notifier.value = ProfileRefreshEvent.postsOnly();
  }
}
