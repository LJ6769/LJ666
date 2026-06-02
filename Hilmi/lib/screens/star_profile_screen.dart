import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/data/user_public_repository.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/star_public_profile.dart';
import 'package:hilmi/utils/open_circle_post.dart';
import 'package:hilmi/utils/open_direct_chat.dart';
import 'package:hilmi/utils/open_direct_video_call.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/user_handle.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';
import 'package:hilmi/widgets/circle/circle_feed_post_pager.dart';
import 'package:hilmi/widgets/circle/circle_feed_vertical_post_list.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/follow/follow_action_button.dart';
import 'package:hilmi/widgets/star_profile/star_profile_assets.dart';

/// 明星个人中心（点击 Discover 明星卡进入）。
class StarProfileScreen extends StatefulWidget {
  const StarProfileScreen({
    super.key,
    required this.story,
    this.repository = const UserPublicRepository(),
    this.circleRepository = const CircleRepository(),
  });

  final ProfileStory story;
  final UserPublicRepository repository;
  final CircleRepository circleRepository;

  static const _designWidth = 375.0;

  /// 与 [StarProfileAssets.headerBg] 边缘色一致，平铺未覆盖处 / 状态栏用。
  static const headerBackground = Color(0xFFDAEBDC);

  /// 资料区与帖子列表底色。
  static const pageBackground = Color(0xFFEFFEF1);

  @override
  State<StarProfileScreen> createState() => _StarProfileScreenState();
}

class _StarProfileScreenState extends State<StarProfileScreen> {
  StarPublicProfile? _profile;
  List<CirclePost> _posts = [];
  bool _loading = true;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / StarProfileScreen._designWidth;

  @override
  void initState() {
    super.initState();
    FollowService.followedIds.addListener(_onSocialStateChanged);
    LikeService.likedPostIds.addListener(_onSocialStateChanged);
    _load();
  }

  @override
  void dispose() {
    FollowService.followedIds.removeListener(_onSocialStateChanged);
    LikeService.likedPostIds.removeListener(_onSocialStateChanged);
    super.dispose();
  }

  void _onSocialStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onPostFollowTap(CirclePost post) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
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

  Future<void> _onPostLikeTap(CirclePost post) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
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

  Future<void> _onPostMoreTap(CirclePost post) async {
    final result = await CirclePostMoreSheet.show(
      context,
      post: post,
      repository: widget.circleRepository,
    );
    if (!mounted || result != CirclePostMoreResult.deleted) return;
    setState(() {
      _posts = _posts.where((p) => p.id != post.id).toList();
    });
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>([
      widget.repository.fetchProfile(widget.story.id),
      widget.circleRepository.fetchPostsByAuthorId(widget.story.id),
    ]);
    if (!mounted) return;
    final posts = results[1] as List<CirclePost>;
    setState(() {
      _profile = results[0] as StarPublicProfile?;
      _posts = BlockService.filterPosts(posts);
      _loading = false;
    });
  }

  Future<void> _openPostDetail(CirclePost post) async {
    final result = await openCirclePostDetail(
      context,
      post: post,
      isFollowed: FollowService.isFollowing(post.authorId),
      isLiked: LikeService.isLiked(post.id),
    );
    if (result != null && mounted) setState(() {});
  }

  DirectChatPeer get _peer {
    final p = _profile;
    final name = p?.displayName ?? widget.story.name ?? 'User';
    return DirectChatPeer(
      id: widget.story.id,
      name: name,
      email: p?.email ?? widget.story.email,
      avatarUrl: p?.avatarUrl ?? widget.story.imageUrl,
    );
  }

  bool get _isFollowing => FollowService.isFollowing(widget.story.id);

  bool get _isSelf =>
      AuthService.cachedProfile?.id.trim() == widget.story.id.trim();

  Future<void> _onChatTap() async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
    }
    if (!mounted) return;
    await openDirectChat(context, peer: _peer);
  }

  Future<void> _onVideoCallTap() async {
    await openDirectVideoCall(context, peer: _peer);
  }

  Future<void> _onMoreTap() async {
    final result = await CirclePostMoreSheet.showForUser(
      context,
      userId: widget.story.id,
    );
    if (result == CirclePostMoreResult.blacklisted && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: StarProfileScreen.headerBackground,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: StarProfileScreen.pageBackground,
        body: _loading
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
                        isSelf: _isSelf,
                        isFollowing: _isFollowing,
                        onBack: () => Navigator.of(context).pop(),
                        onMore: _onMoreTap,
                        onFollowTap: () => FollowActionButton.handleTap(
                          context,
                          widget.story.id,
                        ),
                        avatarUrl:
                            _profile?.avatarUrl ?? widget.story.imageUrl,
                        avatarCacheKey:
                            _profile?.avatarPath ?? widget.story.imageUrl,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _ProfileBody(
                        scale: s,
                        profile: _profile,
                        story: widget.story,
                        onChatTap: _onChatTap,
                        onVideoCallTap: _onVideoCallTap,
                      ),
                    ),
                    if (_posts.isNotEmpty)
                      CircleFeedVerticalPostList(
                        posts: _posts,
                        followedAuthorIds: FollowService.followedIds.value,
                        likedPostIds: LikeService.likedPostIds.value,
                        hideFollowForAuthorId:
                            _isSelf ? widget.story.id : null,
                        onFollowTap: _onPostFollowTap,
                        onLikeTap: _onPostLikeTap,
                        onMoreTap: _onPostMoreTap,
                        onPostTap: _openPostDetail,
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
                const ColoredBox(color: StarProfileScreen.headerBackground),
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
