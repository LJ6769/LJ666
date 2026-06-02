import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/data/home_placeholder_data.dart';
import 'package:hilmi/data/home_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/screens/bartending_live_list_screen.dart';
import 'package:hilmi/screens/tipsy_bar_list_screen.dart';
import 'package:hilmi/utils/open_direct_chat.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/utils/open_tipsy_bar_chat_room.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/home_feed_cards.dart';
import 'package:hilmi/widgets/home_widgets.dart';

/// 底部导航第一项：Discover 首页信息流。
class DiscoverHomeTab extends StatefulWidget {
  const DiscoverHomeTab({super.key, this.feed});

  final HomeFeedData? feed;

  @override
  State<DiscoverHomeTab> createState() => _DiscoverHomeTabState();
}

class _DiscoverHomeTabState extends State<DiscoverHomeTab> {
  static const _repository = HomeRepository();

  HomeFeedData? _feed;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    _authSubscription = AuthService.onAuthStateChange.listen((_) {
      if (mounted) unawaited(_loadFeed());
    });
    if (widget.feed != null) {
      _feed = widget.feed;
    } else {
      _loadFeed();
    }
  }

  @override
  void dispose() {
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onBlockedIdsChanged() {
    if (!mounted || widget.feed != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadAfterBlockChange();
    });
  }

  void _reloadAfterBlockChange() {
    final base = _feed;
    if (base == null) {
      unawaited(_loadFeed());
      return;
    }
    setState(
      () => _feed = HomeRepository.filterByBlockedHosts(
        base,
        BlockService.blockedIds.value,
      ),
    );
  }

  Future<void> _loadFeed() async {
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }
    final data = await _repository.fetchHomeFeed(
      blockedHostIds: BlockService.blockedIds.value,
    );
    if (!mounted) return;
    setState(() => _feed = data);
  }

  List<ProfileStory> _visibleStories(List<ProfileStory> stories) {
    return stories
        .where((story) => !BlockService.isBlocked(story.id))
        .toList(growable: false);
  }

  void _onStoryProfileTap(ProfileStory story) {
    openStarProfileForUser(
      context,
      userId: story.id,
      name: story.name,
      email: story.email,
      imageUrl: story.imageUrl,
    );
  }

  Future<void> _onStoryChatTap(ProfileStory story) async {
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

  Future<void> _onRefresh() async {
    if (widget.feed != null || _feed == null) return;

    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }
    final data = await _repository.refreshHomeFeed(
      blockedHostIds: BlockService.blockedIds.value,
    );
    if (!mounted) return;
    setState(() => _feed = data);
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed ?? _feed ?? kHomePlaceholderData;
    final profileStories = _visibleStories(feed.profileStories);
    final liveRooms = feed.liveRooms;
    final canRefresh = widget.feed == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeDiscoverHeader(coinBalance: feed.coinBalance),
        Expanded(
          child: _HomeFeedScrollView(
            onRefresh: canRefresh ? _onRefresh : null,
            slivers: [
              SliverToBoxAdapter(
                child: HomeProfileStoriesRow(
                  key: ValueKey(
                    profileStories.map((s) => s.id).join(','),
                  ),
                  stories: profileStories,
                  onProfileTap: _onStoryProfileTap,
                  onChatTap: _onStoryChatTap,
                ),
              ),
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
                child: SizedBox(
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
                ),
              ),
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
                      if (mounted) unawaited(_loadFeed());
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
                    HomeTipsyBarCard.tipsyPhotoVerticalBleed,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < feed.tipsyBarRooms.length; i++)
                        HomeTipsyBarCard(
                          room: feed.tipsyBarRooms[i],
                          photoOnRight: i.isOdd,
                          isFirst: i == 0,
                          isLast: i == feed.tipsyBarRooms.length - 1,
                          onJoinTap: () async {
                            final deleted = await openTipsyBarChatRoom(
                              context,
                              room: feed.tipsyBarRooms[i],
                            );
                            if (mounted && deleted) {
                              unawaited(_loadFeed());
                            }
                          },
                          onMoreTap: () async {
                            final deleted = await openTipsyBarChatRoom(
                              context,
                              room: feed.tipsyBarRooms[i],
                              openAboutRoomOnEnter: true,
                            );
                            if (mounted && deleted) {
                              unawaited(_loadFeed());
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
