// 调酒直播分类列表页（Discover See All 进入）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/bartending_live_list_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/widgets/home_feed_cards.dart';

const _bartendingListPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

class BartendingLiveListScreen extends StatelessWidget {
  const BartendingLiveListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetxScreen<BartendingLiveListController>(
      create: BartendingLiveListController.new,
      builder: (c) => Obx(() {
        final selectedTabIndex = c.selectedTab.value;

        return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: splashBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: splashBackground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Image.asset(
                          'assets/home/btn_back.png',
                          width: 44,
                          height: 44,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Bartending Live',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BartendingLiveListController.tabHorizontalPadding,
                    27,
                    BartendingLiveListController.tabHorizontalPadding,
                    20,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tabs = BartendingLiveListController.tabs;
                      final slotWidth =
                          (constraints.maxWidth -
                                  BartendingLiveListController.tabGap *
                                      (tabs.length - 1)) /
                              tabs.length;
                      final tabHeight = slotWidth *
                          BartendingLiveListController.tabAssetHeight /
                          BartendingLiveListController.tabAssetWidth *
                          BartendingLiveListController.tabHeightScale;

                      return Row(
                        children: [
                          for (var index = 0; index < tabs.length; index++) ...[
                            if (index > 0)
                              const SizedBox(
                                width: BartendingLiveListController.tabGap,
                              ),
                            _CategoryTabButton(
                              width: slotWidth,
                              height: tabHeight,
                              offAsset: tabs[index].offAsset,
                              onAsset: tabs[index].onAsset,
                              selected: index == selectedTabIndex,
                              onTap: () => c.onTabSelected(index),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: c.pageController,
                    onPageChanged: c.onPageChanged,
                    physics: const PageScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      for (var index = 0;
                          index < BartendingLiveListController.tabCount;
                          index++)
                        _BartendingLiveTabList(
                          rooms: c.roomsPerTab[index],
                          loading: c.loadingPerTab[index],
                          isPopularTab:
                              BartendingLiveListController.tabs[index].slug ==
                                  null,
                          onRefresh: () => c.bootstrapTabs(forceRefresh: true),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      }),
    );
  }
}

class _BartendingLiveTabList extends StatelessWidget {
  const _BartendingLiveTabList({
    required this.rooms,
    required this.loading,
    required this.isPopularTab,
    required this.onRefresh,
  });

  final List<LiveRoom> rooms;
  final bool loading;
  final bool isPopularTab;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.black,
      displacement: 28,
      child: _buildRoomList(),
    );
  }

  Widget _buildRoomList() {
    if (loading && rooms.isEmpty) {
      return ListView(
        physics: _bartendingListPhysics,
        children: const [
          SizedBox(
            height: 240,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }

    if (rooms.isEmpty) {
      return CustomScrollView(
        physics: _bartendingListPhysics,
        slivers: const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: HomeFeedEmptyPlaceholder(),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      key: isPopularTab
          ? ValueKey(rooms.map((room) => room.id).join(','))
          : null,
      physics: _bartendingListPhysics,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: rooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return HomeLiveRoomCard(
          room: rooms[index],
          fullWidth: true,
        );
      },
    );
  }
}

class _CategoryTabButton extends StatelessWidget {
  const _CategoryTabButton({
    required this.width,
    required this.height,
    required this.offAsset,
    required this.onAsset,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final double height;
  final String offAsset;
  final String onAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          selected ? onAsset : offAsset,
          width: width,
          height: height,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
