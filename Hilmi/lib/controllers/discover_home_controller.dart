// Discover 首页信息流状态与加载逻辑。
import 'dart:async';

import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/data/home_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/widgets/home_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiscoverHomeController extends GetxController {
  DiscoverHomeController({HomeRepository? repository})
      : _repository = repository ?? const HomeRepository();

  static const storyCardScale = homeProfileStoryCardScale;

  final HomeRepository _repository;
  final feed = Rxn<HomeFeedData>();

  HomeFeedData? _widgetFeed;
  Future<void>? _loadFeedTask;
  StreamSubscription<AuthState>? _authSubscription;

  bool get hasWidgetFeed => _widgetFeed != null;

  void setWidgetFeed(HomeFeedData? data) {
    if (data == null || _widgetFeed != null) return;
    _widgetFeed = data;
    feed.value = data;
  }

  HomeFeedData? get displayFeed => _widgetFeed ?? feed.value;

  @override
  void onInit() {
    super.onInit();
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    _authSubscription = AuthService.onAuthStateChange.listen((state) {
      final event = state.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut) {
        unawaited(loadFeed());
      }
    });
    if (_widgetFeed == null) {
      unawaited(loadFeed());
    }
  }

  @override
  void onClose() {
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    _authSubscription?.cancel();
    super.onClose();
  }

  void _onBlockedIdsChanged() {
    if (_widgetFeed != null) return;
    final base = feed.value;
    if (base == null) return;

    final updated = HomeRepository.filterByBlockedHosts(
      base,
      BlockService.blockedIds.value,
    );
    feed.value = updated;
    FeedDataCache.setHomeFeed(updated);

    // 明星卡仅本地移除/补位，不触发整页刷新。
    if ((updated.liveRooms.length < FeedConfig.liveHomePreviewCount &&
            FeedDataCache.bartendingLivePool == null) ||
        (updated.tipsyBarRooms.length < FeedConfig.tipsyBarHomePreviewCount &&
            FeedDataCache.tipsyBarPool == null)) {
      unawaited(refreshFeed());
    }
  }

  Future<void> loadFeed() {
    final inFlight = _loadFeedTask;
    if (inFlight != null) return inFlight;

    final task = _loadFeedOnce();
    _loadFeedTask = task;
    return task.whenComplete(() {
      if (identical(_loadFeedTask, task)) {
        _loadFeedTask = null;
      }
    });
  }

  Future<void> _loadFeedOnce() async {
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }
    final raw = await _repository.fetchHomeFeed(
      blockedHostIds: BlockService.blockedIds.value,
    );
    feed.value = HomeRepository.filterByBlockedHosts(
      raw,
      BlockService.blockedIds.value,
    );
  }

  Future<void> refreshFeed() async {
    if (_widgetFeed != null || feed.value == null) return;

    final raw = await _repository.refreshHomeFeed(
      blockedHostIds: BlockService.blockedIds.value,
    );
    feed.value = HomeRepository.filterByBlockedHosts(
      raw,
      BlockService.blockedIds.value,
    );
  }
}
