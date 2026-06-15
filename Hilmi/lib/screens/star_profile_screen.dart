// 明星个人中心（Discover 明星卡进入）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/star_profile_controller.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/data/user_public_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/star_public_profile.dart';
import 'package:hilmi/utils/user_handle.dart';
import 'package:hilmi/widgets/circle/circle_feed_post_pager.dart';
import 'package:hilmi/widgets/circle/circle_feed_vertical_post_list.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/follow/follow_action_button.dart';
import 'package:hilmi/widgets/star_profile/star_profile_assets.dart';

/// 明星个人中心（点击 Discover 明星卡进入）。
class StarProfileScreen extends StatelessWidget {
  const StarProfileScreen({
    super.key,
    required this.story,
    this.repository = const UserPublicRepository(),
    this.circleRepository = const CircleRepository(),
  });

  final ProfileStory story;
  final UserPublicRepository repository;
  final CircleRepository circleRepository;

  @override
  Widget build(BuildContext context) {
    return GetxScreen<StarProfileController>(
      create: () => StarProfileController(
        story: story,
        repository: repository,
        circleRepository: circleRepository,
      ),
      builder: (c) => Obx(() {
        final s = c.scale(context);
        final topInset = MediaQuery.viewPaddingOf(context).top;
        final loading = c.loading.value;
        final profile = c.profile.value;
        final posts = c.posts;
        final _ = c.socialRevision.value;
        final isSelf = c.isSelf;
        final isFollowing = c.isFollowing;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: StarProfileController.headerBackground,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: StarProfileController.pageBackground,
            body: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD14D4D),
                      strokeWidth: 2,
                    ),
                  )
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _HeaderSection(
                          scale: s,
                          topInset: topInset,
                          isSelf: isSelf,
                          isFollowing: isFollowing,
                          onBack: () => Navigator.of(context).pop(),
                          onMore: () => c.onMoreTap(context),
                          onFollowTap: () => FollowActionButton.handleTap(
                            context,
                            c.story.id,
                          ),
                          avatarUrl: profile?.avatarUrl ?? c.story.imageUrl,
                          avatarCacheKey:
                              profile?.avatarPath ?? c.story.imageUrl,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _ProfileBody(
                          scale: s,
                          profile: profile,
                          story: c.story,
                          onChatTap: () => c.onChatTap(context),
                          onVideoCallTap: () => c.onVideoCallTap(context),
                        ),
                      ),
                      if (posts.isNotEmpty)
                        CircleFeedVerticalPostList(
                          posts: posts,
                          followedAuthorIds: FollowService.followedIds.value,
                          likedPostIds: LikeService.likedPostIds.value,
                          hideFollowForAuthorId:
                              isSelf ? c.story.id : null,
                          onFollowTap: (post) => c.onPostFollowTap(context, post),
                          onLikeTap: (post) => c.onPostLikeTap(context, post),
                          onMoreTap: (post) => c.onPostMoreTap(context, post),
                          onPostTap: (post) => c.openPostDetail(context, post),
                        )
                      else
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 220 * s,
                            child: const Center(
                              child: CircleFeedEmptyPlaceholder(),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      }),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.scale,
    required this.topInset,
    required this.isSelf,
    required this.isFollowing,
    required this.onBack,
    required this.onMore,
    required this.onFollowTap,
    required this.avatarUrl,
    required this.avatarCacheKey,
  });

  /// 与个人中心 [ProfileTab] 顶栏一致，头像一半在绿底、一半在下方。
  static const _headerPatternHeight = 168.0;
  static const _avatarSize = 108.0;
  static const _avatarOverlap = 54.0;
  static const _avatarCornerRadius = 22.0;
  static const _avatarBorderWidth = 2.5;

  final double scale;
  final double topInset;
  final bool isSelf;
  final bool isFollowing;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onFollowTap;
  final String? avatarUrl;
  final String? avatarCacheKey;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final headerH = _headerPatternHeight * s;
    final avatarSize = _avatarSize * s;
    final avatarCornerRadius = _avatarCornerRadius * s;
    final avatarBorderWidth = _avatarBorderWidth * s;
    final stackHeight =
        topInset + headerH + avatarSize - _avatarOverlap * s;

    return SizedBox(
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + headerH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: StarProfileController.headerBackground),
                Image.asset(
                  StarProfileAssets.headerBg,
                  fit: BoxFit.none,
                  repeat: ImageRepeat.repeat,
                  alignment: Alignment.topLeft,
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ),
          ),
          Positioned(
            top: topInset + 4 * s,
            left: 12 * s,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                StarProfileAssets.btnBack,
                width: 40 * s,
                height: 40 * s,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (!isSelf)
            Positioned(
              top: topInset + 8 * s,
              right: 12 * s,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onFollowTap,
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      isFollowing
                          ? StarProfileAssets.btnFollowed
                          : StarProfileAssets.btnFollowAdd,
                      height: 36 * s,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 8 * s),
                  GestureDetector(
                    onTap: onMore,
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      StarProfileAssets.btnMore,
                      width: 40 * s,
                      height: 40 * s,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 0,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(avatarCornerRadius),
                border: Border.all(
                  color: Colors.black,
                  width: avatarBorderWidth,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _AvatarImage(
                url: avatarUrl,
                cacheKey: avatarCacheKey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({this.url, this.cacheKey});

  final String? url;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedMediaImage(
        url: url!,
        cacheKey: cacheKey,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: Color(0xFFE8E4DC),
          child: Icon(Icons.person, size: 48, color: Color(0xFF9E9E9E)),
        ),
      );
    }
    return const ColoredBox(
      color: Color(0xFFE8E4DC),
      child: Center(
        child: Icon(Icons.person, size: 48, color: Color(0xFF9E9E9E)),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.scale,
    required this.profile,
    required this.story,
    required this.onChatTap,
    required this.onVideoCallTap,
  });

  final double scale;
  final StarPublicProfile? profile;
  final ProfileStory story;
  final VoidCallback onChatTap;
  final VoidCallback onVideoCallTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final name = profile?.displayName ?? story.name ?? 'User';
    final handle = profile?.handle ??
        formatUserHandle(email: story.email, userId: story.id);

    return Padding(
      padding: EdgeInsets.fromLTRB(20 * s, 12 * s, 20 * s, 8 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26 * s,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            handle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14 * s,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(height: 18 * s),
          _IntroBox(scale: s, text: profile?.introText ?? 'No intro yet.'),
          SizedBox(height: 16 * s),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onChatTap,
                  behavior: HitTestBehavior.opaque,
                  child: Image.asset(
                    StarProfileAssets.btnChatNow,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: GestureDetector(
                  onTap: onVideoCallTap,
                  behavior: HitTestBehavior.opaque,
                  child: Image.asset(
                    StarProfileAssets.btnVideoCall,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntroBox extends StatelessWidget {
  const _IntroBox({required this.scale, required this.text});

  final double scale;
  final String text;

  static const _bgAspect = 1005 / 220;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 10 * s);
        final textWidth = width - padding.horizontal;

        final bodyStyle = TextStyle(
          fontSize: 14 * s,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        );
        final introSpan = TextSpan(
          style: bodyStyle,
          children: [
            TextSpan(
              text: 'Intro: ',
              style: bodyStyle.copyWith(
                color: const Color(0xFFD14D4D),
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: text),
          ],
        );

        final painter = TextPainter(
          text: introSpan,
          textDirection: Directionality.of(context),
          maxLines: null,
        )..layout(maxWidth: textWidth);

        final minHeight = width / _bgAspect;
        final height = (painter.height + padding.vertical)
            .clamp(minHeight, double.infinity);

        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                StarProfileAssets.introBoxBg,
                fit: BoxFit.fill,
              ),
              Padding(
                padding: padding,
                child: RichText(text: introSpan),
              ),
            ],
          ),
        );
      },
    );
  }
}
