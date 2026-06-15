// 朋友圈 Circle 信息流状态与加载逻辑。
import 'dart:async';

import 'package:get/get.dart';
import 'package:hilmi/controllers/home_shell_controller.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/circle_guide_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/profile_refresh_signal.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/models/circle_post.dart';

class CircleFeedController extends GetxController {
  CircleFeedController({CircleRepository? repository})
      : repository = repository ?? const CircleRepository();

  final CircleRepository repository;

  final allPosts = <CirclePost>[].obs;
  final followedPosts = <CirclePost>[].obs;
  final loading = true.obs;
  final followedLoading = false.obs;
  final refreshing = false.obs;
  final pullExtent = 0.0.obs;
  final tabIndex = 0.obs;
  final feedPageIndex = 0.obs;
  final feedSession = 0.obs;

  int _loadGeneration = 0;
  bool _guideEligibilityChecked = false;
  Future<void>? _loadInFlight;
  Future<void>? _followedLoadInFlight;
  bool _queuedLoadForceRefresh = false;
  bool _queuedLoadAfterPublish = false;
  Worker? _tabWorker;
  Set<String> _followedIdsSnapshot = {};

  List<CirclePost> get visiblePosts {
    final pool = tabIndex.value == 1 ? followedPosts : allPosts;
    return BlockService.filterPosts(pool);
  }

  @override
  void onInit() {
    super.onInit();
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    _followedIdsSnapshot = Set<String>.from(FollowService.followedIds.value);
    FollowService.followedIds.addListener(_onFollowedIdsChanged);
    unawaited(_bootstrap());

    final shell = Get.find<HomeShellController>();
    if (shell.selectedTab.value == HomeShellController.circleTabIndex) {
      unawaited(checkSwipeGuide());
    }
    _tabWorker = ever<int>(shell.selectedTab, (index) {
      if (index == HomeShellController.circleTabIndex) {
        unawaited(checkSwipeGuide());
      }
    });
  }

  @override
  void onClose() {
    _tabWorker?.dispose();
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    FollowService.followedIds.removeListener(_onFollowedIdsChanged);
    super.onClose();
  }

  Future<void> checkSwipeGuide() async {
    if (_guideEligibilityChecked) return;
    _guideEligibilityChecked = true;
    final completed = await CircleGuideService.hasCompletedCircleGuide();
    if (completed) return;
    Get.find<HomeShellController>().setCircleSwipeGuide(true);
  }

  Future<void> _bootstrap() async {
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }
    await load();
  }

  void _onBlockedIdsChanged() {
    followedPosts.assignAll(
      BlockService.filterPosts(followedPosts.toList(growable: false)),
    );
    if (tabIndex.value == 0) {
      unawaited(_reloadPopularAfterBlock());
      return;
    }
    allPosts.refresh();
  }

  Future<void> _reloadPopularAfterBlock() async {
    final previousIndex = feedPageIndex.value;
    final previousLength =
        BlockService.filterPosts(allPosts.toList(growable: false)).length;
    final posts = await repository.fetchPopularPosts(
      blockedAuthorIds: BlockService.blockedIds.value,
    );
    if (isClosed) return;

    final postsChanged =
        _postsIdentityChanged(allPosts.toList(growable: false), posts);
    allPosts.assignAll(posts);
    loading.value = false;

    if (posts.isEmpty) {
      feedPageIndex.value = 0;
      feedSession.value++;
    } else if (postsChanged || posts.length != previousLength) {
      feedPageIndex.value = previousIndex.clamp(0, posts.length - 1);
      feedSession.value++;
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final id in a) {
      if (!b.contains(id)) return false;
    }
    return true;
  }

  void _onFollowedIdsChanged() {
    final current = FollowService.followedIds.value;
    if (_setEquals(_followedIdsSnapshot, current)) return;

    final previous = _followedIdsSnapshot;
    _followedIdsSnapshot = Set<String>.from(current);

    final userId = AuthService.cachedProfile?.id.trim() ?? '';
    if (userId.isNotEmpty) {
      FeedDataCache.invalidateCircleFollowedPosts(userId);
    }

    if (tabIndex.value != 1) return;

    final removedIds = previous.difference(current);
    final addedIds = current.difference(previous);

    if (removedIds.isNotEmpty) {
      final filtered = followedPosts
          .where((post) => current.contains(post.authorId))
          .toList(growable: false);
      followedPosts.assignAll(filtered);
      feedPageIndex.value = filtered.isEmpty
          ? 0
          : feedPageIndex.value.clamp(0, filtered.length - 1);
      feedSession.value++;
      if (userId.isNotEmpty) {
        FeedDataCache.setCircleFollowedPosts(
          userId,
          posts: filtered,
          followedIds: current,
        );
      }
    }

    if (addedIds.isNotEmpty) {
      unawaited(loadFollowed(forceRefresh: true));
    }
  }

  bool _postsIdentityChanged(List<CirclePost> before, List<CirclePost> after) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      if (before[i].id != after[i].id) return true;
    }
    return false;
  }

  Future<void> load({
    bool forceRefresh = false,
    bool afterPublish = false,
  }) async {
    if (_loadInFlight != null) {
      _queuedLoadForceRefresh = _queuedLoadForceRefresh || forceRefresh;
      _queuedLoadAfterPublish = _queuedLoadAfterPublish || afterPublish;
      return _loadInFlight!;
    }

    final run = _runLoad(
      forceRefresh: forceRefresh,
      afterPublish: afterPublish,
    );
    _loadInFlight = run;
    try {
      await run;
    } finally {
      _loadInFlight = null;
      if (_queuedLoadForceRefresh || _queuedLoadAfterPublish) {
        final queuedForce = _queuedLoadForceRefresh;
        final queuedPublish = _queuedLoadAfterPublish;
        _queuedLoadForceRefresh = false;
        _queuedLoadAfterPublish = false;
        await load(
          forceRefresh: queuedForce,
          afterPublish: queuedPublish,
        );
      }
    }
  }

  Future<void> _runLoad({
    required bool forceRefresh,
    required bool afterPublish,
  }) async {
    final generation = ++_loadGeneration;
    final posts = await repository.fetchPopularPosts(
      forceRefresh: forceRefresh,
      blockedAuthorIds: BlockService.blockedIds.value,
    );
    if (generation != _loadGeneration) return;

    final previousIndex = feedPageIndex.value;
    final postsChanged =
        _postsIdentityChanged(allPosts.toList(growable: false), posts);

    if (afterPublish) {
      tabIndex.value = 0;
      feedPageIndex.value = 0;
    }
    allPosts.assignAll(posts);
    loading.value = false;
    refreshing.value = false;
    pullExtent.value = 0;

    if (posts.isEmpty) {
      feedPageIndex.value = 0;
      if (forceRefresh) feedSession.value++;
    } else if (forceRefresh || postsChanged || afterPublish) {
      if (!afterPublish) {
        feedPageIndex.value = previousIndex.clamp(0, posts.length - 1);
      }
      feedSession.value++;
    }
  }

  Future<void> refreshFeed() async {
    if (refreshing.value) return;
    refreshing.value = true;
    pullExtent.value = 0;
    if (tabIndex.value == 1) {
      await loadFollowed(forceRefresh: true);
    } else {
      await load(forceRefresh: true);
    }
  }

  void onPullExtentChanged(double extent) {
    if (feedPageIndex.value != 0 || refreshing.value) return;
    if (pullExtent.value == extent) return;
    pullExtent.value = extent;
  }

  void onTabSelected(int index) {
    if (tabIndex.value == index) return;
    tabIndex.value = index;
    feedPageIndex.value = 0;
    pullExtent.value = 0;
    feedSession.value++;
    if (index == 1) {
      unawaited(loadFollowed());
    }
  }

  Future<void> loadFollowed({bool forceRefresh = false}) async {
    if (!forceRefresh && followedPosts.isNotEmpty) {
      return;
    }

    if (_followedLoadInFlight != null) {
      return _followedLoadInFlight!;
    }

    final run = _runLoadFollowed(forceRefresh: forceRefresh);
    _followedLoadInFlight = run;
    try {
      await run;
    } finally {
      _followedLoadInFlight = null;
    }
  }

  Future<void> _runLoadFollowed({required bool forceRefresh}) async {
    final followedIds = FollowService.followedIds.value;
    if (followedIds.isEmpty) {
      followedPosts.clear();
      feedPageIndex.value = 0;
      refreshing.value = false;
      pullExtent.value = 0;
      return;
    }

    final userId = AuthService.cachedProfile?.id.trim() ?? '';
    if (!forceRefresh && followedPosts.isEmpty && userId.isNotEmpty) {
      final cached = FeedDataCache.circleFollowedPosts(userId, followedIds);
      if (cached != null) {
        followedPosts.assignAll(
          BlockService.filterPosts(cached),
        );
        feedPageIndex.value = 0;
        feedSession.value++;
        refreshing.value = false;
        pullExtent.value = 0;
        return;
      }
    }

    followedLoading.value = true;
    try {
      final posts = await repository.fetchFollowedPosts(
        userId: userId,
        followedAuthorIds: followedIds,
        blockedAuthorIds: BlockService.blockedIds.value,
        forceRefresh: forceRefresh,
      );
      followedPosts.assignAll(posts);
      if (posts.isEmpty) {
        feedPageIndex.value = 0;
      } else {
        feedPageIndex.value =
            feedPageIndex.value.clamp(0, posts.length - 1);
      }
      feedSession.value++;
    } finally {
      followedLoading.value = false;
      refreshing.value = false;
      pullExtent.value = 0;
    }
  }

  Future<bool> onEditPostPublished() async {
    await load(forceRefresh: true, afterPublish: true);
    ProfileRefreshSignal.notifyPostsOnly();
    return true;
  }

  void removePostFromFeed(CirclePost post) {
    final updatedPopular =
        allPosts.where((p) => p.id != post.id).toList(growable: false);
    final updatedFollowed =
        followedPosts.where((p) => p.id != post.id).toList(growable: false);
    if (updatedPopular.length == allPosts.length &&
        updatedFollowed.length == followedPosts.length) {
      return;
    }
    final active = tabIndex.value == 1 ? updatedFollowed : updatedPopular;
    final nextIndex = active.isEmpty
        ? 0
        : feedPageIndex.value.clamp(0, active.length - 1);
    allPosts.assignAll(updatedPopular);
    followedPosts.assignAll(updatedFollowed);
    feedPageIndex.value = nextIndex;
    feedSession.value++;
    ProfileRefreshSignal.notify();
  }

  void onFeedPageChanged(int index) {
    feedPageIndex.value = index;
    if (index != 0) pullExtent.value = 0;
  }
}
