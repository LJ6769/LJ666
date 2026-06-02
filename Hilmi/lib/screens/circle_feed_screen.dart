import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/core/profile_refresh_signal.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/circle/circle_filter_tabs.dart';
import 'package:hilmi/core/circle_guide_service.dart';
import 'package:hilmi/widgets/circle/circle_feed_post_pager.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';
import 'package:hilmi/utils/open_circle_edit_post.dart';
import 'package:hilmi/utils/open_circle_post.dart';
import 'package:hilmi/utils/open_login_screen.dart';

/// 底部导航第二项：朋友圈 Circle 信息流。
class CircleFeedScreen extends StatefulWidget {
  const CircleFeedScreen({
    super.key,
    this.repository = const CircleRepository(),
    this.isTabActive = false,
    this.onSwipeGuideChanged,
  });

  final CircleRepository repository;

  /// 底部导航是否选中朋友圈 Tab。
  final bool isTabActive;

  /// 首次滑动引导显隐（由 [HomePage] 全屏蒙版承接）。
  final ValueChanged<bool>? onSwipeGuideChanged;

  @override
  State<CircleFeedScreen> createState() => _CircleFeedScreenState();
}

class _CircleFeedScreenState extends State<CircleFeedScreen> {
  List<CirclePost> _allPosts = [];
  bool _loading = true;
  bool _refreshing = false;
  double _pullExtent = 0;
  int _tabIndex = 0;
  int _feedPageIndex = 0;
  int _feedSession = 0;
  int _loadGeneration = 0;
  bool _guideEligibilityChecked = false;
  Future<void>? _loadInFlight;
  bool _queuedLoadForceRefresh = false;
  bool _queuedLoadAfterPublish = false;

  List<CirclePost> _visiblePosts(Set<String> followedIds) {
    final pool = BlockService.filterPosts(_allPosts);
    if (_tabIndex == 1) {
      return widget.repository.filterFollowedPosts(pool, followedIds);
    }
    return pool;
  }

  @override
  void initState() {
    super.initState();
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    if (AuthService.isLoggedIn) {
      AuthService.loadCurrentProfile();
    }
    _load();
    if (widget.isTabActive) {
      _checkSwipeGuide();
    }
  }

  @override
  void didUpdateWidget(covariant CircleFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _checkSwipeGuide();
    }
  }

  Future<void> _checkSwipeGuide() async {
    if (_guideEligibilityChecked) return;
    _guideEligibilityChecked = true;
    final completed = await CircleGuideService.hasCompletedCircleGuide();
    if (!mounted || completed) return;
    widget.onSwipeGuideChanged?.call(true);
  }

  @override
  void dispose() {
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    super.dispose();
  }

  /// 列表 id 顺序变化（拉黑补位、下拉刷新等）才重建 PageView；点赞不改变。
  bool _postsIdentityChanged(List<CirclePost> before, List<CirclePost> after) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      if (before[i].id != after[i].id) return true;
    }
    return false;
  }

  void _onBlockedIdsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _load({
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
        await _load(
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
    final posts = await widget.repository.fetchPopularPosts(
      forceRefresh: forceRefresh,
      blockedAuthorIds: BlockService.blockedIds.value,
    );
    if (!mounted || generation != _loadGeneration) return;
    final previousIndex = _feedPageIndex;
    final postsChanged = _postsIdentityChanged(_allPosts, posts);
    setState(() {
      if (afterPublish) {
        _tabIndex = 0;
        _feedPageIndex = 0;
      }
      _allPosts = posts;
      _loading = false;
      _refreshing = false;
      _pullExtent = 0;
      if (posts.isEmpty) {
        _feedPageIndex = 0;
      } else if (postsChanged || afterPublish) {
        if (!afterPublish) {
          _feedPageIndex = previousIndex.clamp(0, posts.length - 1);
        }
        _feedSession++;
      }
    });
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _pullExtent = 0;
    });
    await _load(forceRefresh: true);
  }

  void _onPullExtentChanged(double extent) {
    if (_feedPageIndex != 0 || _refreshing) return;
    if (_pullExtent == extent) return;
    setState(() => _pullExtent = extent);
  }

  void _onTabSelected(int index) {
    setState(() {
      _tabIndex = index;
      _feedPageIndex = 0;
      _pullExtent = 0;
    });
  }

  Future<void> _onEditPostTap() async {
    final published = await openCircleEditPost(context);
    if (!mounted || !published) return;
    await _load(forceRefresh: true, afterPublish: true);
    if (!mounted) return;
    ProfileRefreshSignal.notifyPostsOnly();
  }

  Future<void> _onFollowTap(CirclePost post) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      if (!mounted || !AuthService.isLoggedIn) return;
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }
    try {
      await FollowService.toggle(post.authorId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onLikeTap(CirclePost post) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      if (!mounted || !AuthService.isLoggedIn) return;
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }
    try {
      await LikeService.toggle(post.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removePostFromFeed(CirclePost post) {
    final updated =
        _allPosts.where((p) => p.id != post.id).toList(growable: false);
    if (updated.length == _allPosts.length) return;
    final nextIndex = updated.isEmpty
        ? 0
        : _feedPageIndex.clamp(0, updated.length - 1);
    setState(() {
      _allPosts = updated;
      _feedPageIndex = nextIndex;
      _feedSession++;
    });
    ProfileRefreshSignal.notify();
  }

  Future<void> _onMoreTap(CirclePost post) async {
    final result = await CirclePostMoreSheet.show(
      context,
      post: post,
      repository: widget.repository,
    );
    if (!mounted || result == null) return;
    if (result == CirclePostMoreResult.deleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _removePostFromFeed(post);
      });
      return;
    }
    if (result == CirclePostMoreResult.blacklisted) {
      setState(() {});
    }
  }

  Future<void> _openPostDetail(CirclePost post) async {
    final result = await openCirclePostDetail(
      context,
      post: post,
      isFollowed: FollowService.isFollowing(post.authorId),
      isLiked: LikeService.isLiked(post.id),
    );
    if (!mounted) return;
    if (result?.deleted == true) {
      _removePostFromFeed(post);
      return;
    }
    if (result != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: splashBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  CircleAssets.titleCircle,
                  height: 40,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _onEditPostTap,
                  behavior: HitTestBehavior.opaque,
                  child: Image.asset(
                    CircleAssets.btnEditPost,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 24),
            child: CircleFilterTabs(
              selectedIndex: _tabIndex,
              onSelected: _onTabSelected,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD14D4D),
          strokeWidth: 2,
        ),
      );
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: FollowService.followedIds,
      builder: (context, followedIds, _) {
        final posts = _visiblePosts(followedIds);
        return _buildFeedBody(followedIds, posts);
      },
    );
  }

  Widget _buildFeedBody(Set<String> followedIds, List<CirclePost> posts) {
    if (posts.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFD14D4D),
        onRefresh: _onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: const Center(child: CircleFeedEmptyPlaceholder()),
              ),
            );
          },
        ),
      );
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: LikeService.likedPostIds,
      builder: (context, likedPostIds, _) {
        return CircleFeedPostPager(
          key: ValueKey('circle_${_tabIndex}_$_feedSession'),
          posts: posts,
          hideFollowForAuthorId: AuthService.cachedProfile?.id,
          followedAuthorIds: followedIds,
          likedPostIds: likedPostIds,
          onFollowTap: _onFollowTap,
          onLikeTap: _onLikeTap,
          onMoreTap: _onMoreTap,
          onPostTap: _openPostDetail,
          enablePullToRefresh: true,
          onRefresh: _onRefresh,
          onPullExtentChanged: _onPullExtentChanged,
          isRefreshing: _refreshing,
          pullExtent: _pullExtent,
          feedPageIndex: _feedPageIndex,
          onFeedPageChanged: (index) {
            setState(() {
              _feedPageIndex = index;
              if (index != 0) _pullExtent = 0;
            });
          },
        );
      },
    );
  }
}
