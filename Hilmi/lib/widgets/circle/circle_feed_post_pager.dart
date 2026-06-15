// 朋友圈横向翻页列表、空态与下拉刷新。
import 'package:flutter/material.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/circle/circle_feed_layout.dart';
import 'package:hilmi/widgets/circle/circle_post_card.dart';

/// 朋友圈式横向翻页帖子列表（与 [CircleFeedScreen] 列表区一致）。
class CircleFeedPostPager extends StatefulWidget {
  const CircleFeedPostPager({
    super.key,
    required this.posts,
    required this.followedAuthorIds,
    required this.likedPostIds,
    required this.onFollowTap,
    required this.onLikeTap,
    required this.onMoreTap,
    this.onPostTap,
    this.hideFollowForAuthorId,
    this.enablePullToRefresh = false,
    this.onRefresh,
    this.onPullExtentChanged,
    this.isRefreshing = false,
    this.pullExtent = 0,
    this.feedPageIndex = 0,
    this.onFeedPageChanged,
  });

  final List<CirclePost> posts;
  final Set<String> followedAuthorIds;
  final Set<String> likedPostIds;
  final void Function(CirclePost post) onFollowTap;
  final void Function(CirclePost post) onLikeTap;
  final void Function(CirclePost post) onMoreTap;
  final void Function(CirclePost post)? onPostTap;

  /// 个人中心：自己的帖子不显示关注按钮。
  final String? hideFollowForAuthorId;

  final bool enablePullToRefresh;
  final Future<void> Function()? onRefresh;
  final ValueChanged<double>? onPullExtentChanged;
  final bool isRefreshing;
  final double pullExtent;
  final int feedPageIndex;
  final ValueChanged<int>? onFeedPageChanged;

  @override
  State<CircleFeedPostPager> createState() => _CircleFeedPostPagerState();
}

class _CircleFeedPostPagerState extends State<CircleFeedPostPager> {
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: CircleFeedLayout.viewportFraction,
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  double _refreshIndicatorLeft(BuildContext context) {
    final pageWidth = MediaQuery.sizeOf(context).width;
    final gutterWidth =
        pageWidth * (1 - CircleFeedLayout.viewportFraction) / 2;
    const indicatorSize = 24.0;
    final baseLeft =
        ((gutterWidth - indicatorSize) / 2).clamp(4.0, gutterWidth);
    return baseLeft +
        widget.pullExtent.clamp(0.0, gutterWidth * 0.6);
  }

  Widget _buildCard(CirclePost post) {
    final hideFollow =
        widget.hideFollowForAuthorId != null &&
        post.authorId == widget.hideFollowForAuthorId;

    final card = CirclePostCard(
      fillHeight: true,
      post: post,
      hideFollow: hideFollow,
      isFollowed: widget.followedAuthorIds.contains(post.authorId),
      isLiked: widget.likedPostIds.contains(post.id),
      onFollowTap: () => widget.onFollowTap(post),
      onLikeTap: () => widget.onLikeTap(post),
      onMoreTap: () => widget.onMoreTap(post),
    );

    if (widget.onPostTap == null) return card;

    return GestureDetector(
      onTap: () => widget.onPostTap!(post),
      behavior: HitTestBehavior.deferToChild,
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;

    if (posts.isEmpty) {
      return const Center(child: CircleFeedEmptyPlaceholder());
    }

    final controller = _pageController!;

    return Column(
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PageView.builder(
                controller: controller,
                scrollDirection: Axis.horizontal,
                padEnds: true,
                clipBehavior: Clip.none,
                onPageChanged: widget.onFeedPageChanged,
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final card = KeyedSubtree(
                    key: ValueKey(post.id),
                    child: _buildCard(post),
                  );
                  if (index == 0 &&
                      widget.enablePullToRefresh &&
                      widget.onRefresh != null &&
                      widget.onPullExtentChanged != null) {
                    return CircleFeedPullToRefresh(
                      enabled: widget.feedPageIndex == 0 &&
                          !widget.isRefreshing,
                      onPullExtentChanged: widget.onPullExtentChanged!,
                      onRefresh: widget.onRefresh!,
                      child: card,
                    );
                  }
                  return card;
                },
              ),
              if (widget.enablePullToRefresh &&
                  widget.feedPageIndex == 0 &&
                  (widget.isRefreshing || widget.pullExtent > 6))
                Positioned(
                  left: _refreshIndicatorLeft(context),
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: const Color(0xFFD14D4D),
                        strokeWidth: 2,
                        value: widget.isRefreshing
                            ? null
                            : (widget.pullExtent /
                                    CircleFeedPullToRefresh.triggerDistance)
                                .clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (posts.length > 1) ...[
          const SizedBox(height: 8),
          CircleFeedPageIndicator(
            count: posts.length,
            index: widget.feedPageIndex,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// 无帖子时居中鸡尾酒图标。
class CircleFeedEmptyPlaceholder extends StatelessWidget {
  const CircleFeedEmptyPlaceholder({super.key});

  static const _iconSize = 72.0;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CircleAssets.icEmptyFeed,
      width: _iconSize,
      height: _iconSize,
      fit: BoxFit.contain,
    );
  }
}

class CircleFeedPageIndicator extends StatelessWidget {
  const CircleFeedPageIndicator({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${index + 1} / $count',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.black.withValues(alpha: 0.45),
      ),
    );
  }
}

/// 第一条右拉刷新：PageView 边界不产生 overscroll，改用手势检测右拖。
class CircleFeedPullToRefresh extends StatefulWidget {
  const CircleFeedPullToRefresh({
    super.key,
    required this.enabled,
    required this.onPullExtentChanged,
    required this.onRefresh,
    required this.child,
  });

  static const triggerDistance = 56.0;

  final bool enabled;
  final ValueChanged<double> onPullExtentChanged;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<CircleFeedPullToRefresh> createState() =>
      _CircleFeedPullToRefreshState();
}

class _CircleFeedPullToRefreshState extends State<CircleFeedPullToRefresh> {
  double _pullExtent = 0;
  int? _activePointer;
  bool _refreshTriggered = false;

  void _notifyPullExtent(double extent) {
    if (_pullExtent == extent) return;
    _pullExtent = extent;
    widget.onPullExtentChanged(extent);
  }

  void _resetPull() {
    if (_pullExtent == 0 && _activePointer == null && !_refreshTriggered) {
      return;
    }
    _pullExtent = 0;
    _activePointer = null;
    _refreshTriggered = false;
    widget.onPullExtentChanged(0);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _activePointer = event.pointer;
    _pullExtent = 0;
    _refreshTriggered = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.enabled ||
        _activePointer != event.pointer ||
        _refreshTriggered) {
      return;
    }

    final dx = event.delta.dx;
    if (dx > 0) {
      _notifyPullExtent(
        (_pullExtent + dx)
            .clamp(0.0, CircleFeedPullToRefresh.triggerDistance * 1.5),
      );
    } else if (dx < -1 && _pullExtent > 0) {
      _notifyPullExtent(
        (_pullExtent + dx)
            .clamp(0.0, CircleFeedPullToRefresh.triggerDistance * 1.5),
      );
    }
  }

  Future<void> _onPointerEnd() async {
    if (!widget.enabled) {
      _resetPull();
      return;
    }
    if (_refreshTriggered) {
      _resetPull();
      return;
    }

    if (_pullExtent >= CircleFeedPullToRefresh.triggerDistance) {
      _refreshTriggered = true;
      try {
        await widget.onRefresh();
      } finally {
        if (mounted) _resetPull();
      }
    } else {
      _resetPull();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _onPointerEnd(),
      onPointerCancel: (_) => _onPointerEnd(),
      child: widget.child,
    );
  }
}
