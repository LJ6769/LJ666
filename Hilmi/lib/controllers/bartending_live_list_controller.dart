// 调酒直播分类列表页状态与加载逻辑。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/data/home_repository.dart';
import 'package:hilmi/models/home_models.dart';

class BartendingLiveListController extends GetxController {
  BartendingLiveListController({HomeRepository? repository})
      : _repository = repository ?? const HomeRepository();

  static const tabCount = 3;

  static const tabs = <({
    String? slug,
    String offAsset,
    String onAsset,
  })>[
    (
      slug: null,
      offAsset: 'assets/home/tab_popular_off.png',
      onAsset: 'assets/home/tab_popular_on.png',
    ),
    (
      slug: 'tutorials',
      offAsset: 'assets/home/tab_tutorials_off.png',
      onAsset: 'assets/home/tab_tutorials_on.png',
    ),
    (
      slug: 'other',
      offAsset: 'assets/home/tab_other_off.png',
      onAsset: 'assets/home/tab_other_on.png',
    ),
  ];

  static const tabAssetWidth = 315.0;
  static const tabAssetHeight = 111.0;
  static const tabGap = 8.0;
  static const tabHorizontalPadding = 28.0;
  static const tabHeightScale = 1.14;

  final HomeRepository _repository;
  late final PageController pageController;
  final selectedTab = 0.obs;
  late final RxList<List<LiveRoom>> roomsPerTab;
  late final RxList<bool> loadingPerTab;
  late final RxList<bool> loadedPerTab;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: selectedTab.value);
    roomsPerTab = RxList<List<LiveRoom>>.generate(tabCount, (_) => const []);
    loadingPerTab = RxList<bool>.generate(tabCount, (_) => false);
    loadedPerTab = RxList<bool>.generate(tabCount, (_) => false);
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    unawaited(bootstrapTabs());
  }

  @override
  void onClose() {
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    pageController.dispose();
    super.onClose();
  }

  void _onBlockedIdsChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        unawaited(reloadLoadedTabsFromCache());
      }
    });
  }

  Future<void> bootstrapTabs({bool forceRefresh = false}) async {
    for (var i = 0; i < tabCount; i++) {
      loadingPerTab[i] = true;
    }
    loadingPerTab.refresh();

    await _repository.ensureBartendingLivePool(forceRefresh: forceRefresh);

    for (var i = 0; i < tabCount; i++) {
      await loadRooms(tabIndex: i, forceRefresh: false, reload: forceRefresh);
    }
  }

  Future<void> reloadLoadedTabsFromCache() async {
    for (var i = 0; i < tabCount; i++) {
      if (loadedPerTab[i]) {
        await loadRooms(tabIndex: i, reload: true);
      }
    }
  }

  Future<void> loadRooms({
    required int tabIndex,
    bool forceRefresh = false,
    bool reload = false,
  }) async {
    if (tabIndex < 0 || tabIndex >= tabCount) return;
    if (!reload && !forceRefresh && loadedPerTab[tabIndex]) return;

    if (!forceRefresh && !reload) {
      loadingPerTab[tabIndex] = true;
      loadingPerTab.refresh();
    }

    if (forceRefresh) {
      await _repository.ensureBartendingLivePool(forceRefresh: true);
    }

    final rooms = await _repository.fetchBartendingLiveList(
      categorySlug: tabs[tabIndex].slug,
      blockedHostIds: BlockService.blockedIds.value,
      forceRefresh: false,
    );
    if (isClosed) return;
    roomsPerTab[tabIndex] = rooms;
    loadingPerTab[tabIndex] = false;
    loadedPerTab[tabIndex] = true;
    roomsPerTab.refresh();
    loadingPerTab.refresh();
    loadedPerTab.refresh();
  }

  void onTabSelected(int index) {
    if (index == selectedTab.value) return;
    selectedTab.value = index;
    unawaited(loadRooms(tabIndex: index));
    pageController.jumpToPage(index);
  }

  void onPageChanged(int index) {
    if (index == selectedTab.value) return;
    selectedTab.value = index;
    unawaited(loadRooms(tabIndex: index));
  }
}
