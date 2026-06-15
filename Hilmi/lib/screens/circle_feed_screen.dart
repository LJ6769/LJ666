// 底部 Tab：朋友圈 Circle 横向翻页信息流。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/circle_feed_controller.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/open_circle_edit_post.dart';
import 'package:hilmi/utils/open_circle_post.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/circle/circle_feed_post_pager.dart';
import 'package:hilmi/widgets/circle/circle_filter_tabs.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';

/// 底部导航第二项：朋友圈 Circle 信息流。
class CircleFeedScreen extends GetView<CircleFeedController> {
  const CircleFeedScreen({super.key});

  Future<void> _onEditPostTap(BuildContext context) async {
    final published = await openCircleEditPost(context);
    if (!published) return;
    await controller.onEditPostPublished();
  }

  Future<void> _onFollowTap(BuildContext context, CirclePost post) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      if (!AuthService.isLoggedIn) return;
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }
    try {
      await FollowService.toggle(post.authorId);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onLikeTap(BuildContext context, CirclePost post) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      if (!AuthService.isLoggedIn) return;
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }
    try {
      await LikeService.toggle(post.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onMoreTap(BuildContext context, CirclePost post) async {
    final result = await CirclePostMoreSheet.show(
      context,
      post: post,
      repository: controller.repository,
    );
    if (result == null) return;
    if (result == CirclePostMoreResult.deleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.removePostFromFeed(post);
      });
    }
  }

  Future<void> _openPostDetail(BuildContext context, CirclePost post) async {
    final result = await openCirclePostDetail(
      context,
      post: post,
      isFollowed: FollowService.isFollowing(post.authorId),
      isLiked: LikeService.isLiked(post.id),
    );
    if (result?.deleted == true) {
      controller.removePostFromFeed(post);
    }
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
                  onTap: () => _onEditPostTap(context),
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
            child: Obx(
              () => CircleFilterTabs(
                selectedIndex: controller.tabIndex.value,
                onSelected: controller.onTabSelected,
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      final tabIndex = controller.tabIndex.value;
      final loading = tabIndex == 1
          ? controller.followedLoading.value
          : controller.loading.value;
      if (loading && !controller.refreshing.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD14D4D),
            strokeWidth: 2,
          ),
        );
      }

      // 在 Obx 内读取列表，刷新后 assignAll 才会触发重建。
      final posts = controller.visiblePosts;

      return ValueListenableBuilder<Set<String>>(
        valueListenable: FollowService.followedIds,
        builder: (context, followedIds, _) {
          return _buildFeedBody(context, followedIds, posts);
        },
      );
    });
  }

  Widget _buildFeedBody(
    BuildContext context,
    Set<String> followedIds,
    List<CirclePost> posts,
  ) {
    if (posts.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFD14D4D),
        onRefresh: controller.refreshFeed,
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
        return Obx(
          () => CircleFeedPostPager(
            key: ValueKey(
              'circle_${controller.tabIndex.value}_${controller.feedSession.value}',
            ),
            posts: posts,
            hideFollowForAuthorId: AuthService.cachedProfile?.id,
            followedAuthorIds: followedIds,
            likedPostIds: likedPostIds,
            onFollowTap: (post) => _onFollowTap(context, post),
            onLikeTap: (post) => _onLikeTap(context, post),
            onMoreTap: (post) => _onMoreTap(context, post),
            onPostTap: (post) => _openPostDetail(context, post),
            enablePullToRefresh: true,
            onRefresh: controller.refreshFeed,
            onPullExtentChanged: controller.onPullExtentChanged,
            isRefreshing: controller.refreshing.value,
            pullExtent: controller.pullExtent.value,
            feedPageIndex: controller.feedPageIndex.value,
            onFeedPageChanged: controller.onFeedPageChanged,
          ),
        );
      },
    );
  }
}
