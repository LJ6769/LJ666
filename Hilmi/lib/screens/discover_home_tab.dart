// 底部 Tab：Discover 首页信息流与明星横滑。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/discover_home_controller.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/screens/bartending_live_list_screen.dart';
import 'package:hilmi/screens/tipsy_bar_list_screen.dart';
import 'package:hilmi/utils/open_direct_chat.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/utils/open_tipsy_bar_about_sheet.dart';
import 'package:hilmi/utils/open_tipsy_bar_chat_room.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_about_room_sheet.dart';
import 'package:hilmi/widgets/home_feed_cards.dart';
import 'package:hilmi/widgets/home_widgets.dart';

/// 底部导航第一项：Discover 首页信息流。
class DiscoverHomeTab extends GetView<DiscoverHomeController> {
  const DiscoverHomeTab({super.key, this.feed});

  final HomeFeedData? feed;

  void _onStoryProfileTap(BuildContext context, ProfileStory story) {
    openStarProfileForUser(
      context,
      userId: story.id,
      name: story.name,
      email: story.email,
      imageUrl: story.imageUrl,
    );
  }

  Future<void> _onStoryChatTap(BuildContext context, ProfileStory story) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
    }
    final name = story.name?.trim();
    await openDirectChat(
      context,
      peer: DirectChatPeer(
        id: story.id,
        name: name != null && name.isNotEmpty ? name : 'User',
        email: story.email,
        avatarUrl: story.imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (feed != null) {
      controller.setWidgetFeed(feed);
    }

    return Obx(() {
      final data = controller.displayFeed;
      if (data == null) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFD14D4D),
          ),
        );
      }

      final profileStories = data.profileStories;
      final liveRooms = data.liveRooms;
      final tipsyBarRooms = data.tipsyBarRooms;
      final hasStories = profileStories.isNotEmpty;
      final hasLive = liveRooms.isNotEmpty;
      final canRefresh = !controller.hasWidgetFeed;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeDiscoverHeader(coinBalance: data.coinBalance),
          Expanded(
            child: _HomeFeedScrollView(
              onRefresh: canRefresh ? controller.refreshFeed : null,
              slivers: [
                SliverToBoxAdapter(
                  child: HomeProfileStoriesRow(
                    key: ValueKey(
                      profileStories.map((s) => s.id).join(','),
                    ),
                    stories: profileStories,
                    cardScale: DiscoverHomeController.storyCardScale,
                    onProfileTap: (story) => _onStoryProfileTap(context, story),
                    onChatTap: (story) => _onStoryChatTap(context, story),
                  ),
                ),
                if (hasStories)
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: HomeSectionHeader(
                      iconAsset: 'assets/home/icon_bartending.png',
                      onSeeAll: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BartendingLiveListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: hasLive
                      ? SizedBox(
                          height: liveCardHeightForScreenWidth(
                            MediaQuery.sizeOf(context).width,
                          ),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 20),
                            itemCount: liveRooms.length,
                            itemBuilder: (context, index) {
                              return HomeLiveRoomCard(room: liveRooms[index]);
                            },
                          ),
                        )
                      : const _HomeFeedCompactEmptySection(),
                ),
                if (hasLive)
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: HomeSectionHeader(
                      iconAsset: 'assets/home/icon_tipsy.png',
                      onSeeAll: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TipsyBarListScreen(),
                          ),
                        );
                        await controller.loadFeed();
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      tipsyBarRooms.isEmpty
                          ? 8
                          : HomeTipsyBarCard.tipsyPhotoVerticalBleed,
                    ),
                    child: tipsyBarRooms.isEmpty
                        ? const _HomeFeedCompactEmptySection()
                        : Column(
                            children: [
                              for (var i = 0;
                                  i < tipsyBarRooms.length;
                                  i++)
                                HomeTipsyBarCard(
                                  room: tipsyBarRooms[i],
                                  photoOnRight: i.isOdd,
                                  isFirst: i == 0,
                                  isLast: i == tipsyBarRooms.length - 1,
                                  onJoinTap: () async {
                                    final deleted =
                                        await openTipsyBarChatRoom(
                                      context,
                                      room: tipsyBarRooms[i],
                                    );
                                    if (deleted) {
                                      await controller.loadFeed();
                                    }
                                  },
                                  onMoreTap: () async {
                                    final result =
                                        await openTipsyBarAboutSheet(
                                      context,
                                      tipsyBarRooms[i],
                                    );
                                    if (result ==
                                        TipsyBarMoreResult.deleted) {
                                      await controller.loadFeed();
                                    }
                                  },
                                ),
                            ],
                          ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// 无数据时紧凑空态（不占卡片列表高度，让下一区块顶上来）。
class _HomeFeedCompactEmptySection extends StatelessWidget {
  const _HomeFeedCompactEmptySection();

  static const _verticalPadding = 20.0;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: _verticalPadding),
      child: Center(child: HomeFeedEmptyPlaceholder()),
    );
  }
}

class _HomeFeedScrollView extends StatelessWidget {
  const _HomeFeedScrollView({
    required this.slivers,
    this.onRefresh,
  });

  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: slivers,
    );

    if (onRefresh == null) {
      return scrollView;
    }

    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: Colors.black,
      displacement: 28,
      child: scrollView,
    );
  }
}
