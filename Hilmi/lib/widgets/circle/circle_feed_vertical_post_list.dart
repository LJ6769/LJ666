// 个人中心 My Post/My Like 纵向同款大卡列表。
import 'package:flutter/material.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/widgets/circle/circle_feed_layout.dart';
import 'package:hilmi/widgets/circle/circle_post_card.dart';

/// 朋友圈同款大卡，纵向列表（个人中心 My Post / My Like）。
class CircleFeedVerticalPostList extends StatelessWidget {
  const CircleFeedVerticalPostList({
    super.key,
    required this.posts,
    required this.followedAuthorIds,
    required this.likedPostIds,
    required this.onFollowTap,
    required this.onLikeTap,
    required this.onMoreTap,
    this.onPostTap,
    this.hideFollowForAuthorId,
  });

  final List<CirclePost> posts;
  final Set<String> followedAuthorIds;
  final Set<String> likedPostIds;
  final void Function(CirclePost post) onFollowTap;
  final void Function(CirclePost post) onLikeTap;
  final void Function(CirclePost post) onMoreTap;
  final void Function(CirclePost post)? onPostTap;
  final String? hideFollowForAuthorId;

  @override
  Widget build(BuildContext context) {
    final cardHeight = CircleFeedLayout.profileVerticalPostCardHeight(context);
    final cardWidth = CircleFeedLayout.cardWidth(context);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = posts[index];
          final hideFollow =
              hideFollowForAuthorId != null &&
              post.authorId == hideFollowForAuthorId;

          final card = SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: CirclePostCard(
              fillHeight: true,
              post: post,
              hideFollow: hideFollow,
              isFollowed: followedAuthorIds.contains(post.authorId),
              isLiked: likedPostIds.contains(post.id),
              onFollowTap: () => onFollowTap(post),
              onLikeTap: () => onLikeTap(post),
              onMoreTap: () => onMoreTap(post),
            ),
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: index < posts.length - 1 ? 16 : 24,
            ),
            child: Center(
              child: onPostTap == null
                  ? card
                  : GestureDetector(
                      onTap: () => onPostTap!(post),
                      behavior: HitTestBehavior.deferToChild,
                      child: card,
                    ),
            ),
          );
        },
        childCount: posts.length,
      ),
    );
  }
}
