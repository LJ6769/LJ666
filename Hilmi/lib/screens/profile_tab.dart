import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/core/profile_refresh_signal.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/open_circle_post.dart';
import 'package:hilmi/utils/open_edit_profile.dart';
import 'package:hilmi/utils/open_coins_store.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/open_settings_screen.dart';
import 'package:hilmi/utils/user_handle.dart';
import 'package:hilmi/widgets/circle/circle_feed_vertical_post_list.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/profile/profile_assets.dart';
import 'package:hilmi/widgets/profile/profile_filter_tabs.dart';

/// 个人中心（Mine）：资料区 + My Post / My Like 朋友圈式卡片列表。
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    this.repository = const CircleRepository(),
  });

  final CircleRepository repository;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const _headerPatternHeight = 168.0;
  static const _avatarSize = 108.0;
  /// 头像探入顶栏的高度（勿用于负 padding）。
  static const _avatarOverlap = 54.0;

  UserProfile? _profile;
  List<CirclePost> _myPosts = [];
  List<CirclePost> _likedPosts = [];
  bool _loadingProfile = true;
  bool _loadingPosts = true;
  int _tabIndex = 0;

  List<CirclePost> get _visiblePosts => _tabIndex == 0 ? _myPosts : _likedPosts;

  void _onProfileRefreshSignal() {
    if (!mounted) return;
    final event = ProfileRefreshSignal.notifier.value;
    if (event.postsOnly) {
      unawaited(_refreshPostsOnly());
    } else {
      unawaited(_loadAll());
    }
  }

  /// 不重拉资料，避免 applyFromProfile 牵动朋友圈列表二次刷新。
  Future<void> _refreshPostsOnly() async {
    if (!mounted) return;
    var profile = _profile ?? AuthService.cachedProfile;
    profile ??= await AuthService.loadCurrentProfile();
    if (!mounted) return;
    if (profile == null) {
      await _loadAll();
      return;
    }
    setState(() {
      _profile = profile;
      _loadingPosts = true;
    });
    await _loadPosts(profile);
  }

  @override
  void initState() {
    super.initState();
    ProfileRefreshSignal.notifier.addListener(_onProfileRefreshSignal);
    FollowService.followedIds.addListener(_onFollowIdsChanged);
    BlockService.blockedIds.addListener(_onFollowIdsChanged);
    LikeService.likedPostIds.addListener(_onLikedIdsChanged);
    _loadAll();
  }

  @override
  void dispose() {
    ProfileRefreshSignal.notifier.removeListener(_onProfileRefreshSignal);
    FollowService.followedIds.removeListener(_onFollowIdsChanged);
    BlockService.blockedIds.removeListener(_onFollowIdsChanged);
    LikeService.likedPostIds.removeListener(_onLikedIdsChanged);
    super.dispose();
  }

  void _onFollowIdsChanged() {
    if (!mounted) return;
    setState(() {
      _likedPosts = BlockService.filterPosts(_likedPosts);
    });
  }

  Future<void> _onLikedIdsChanged() async {
    if (!mounted) return;
    final profile = _profile;
    if (profile == null) return;
    final ids = LikeService.likedPostIds.value.toList();
    final posts = await widget.repository.fetchPostsByIds(ids);
    if (!mounted) return;
    setState(() {
      _likedPosts = BlockService.filterPosts(posts);
    });
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loadingProfile = true;
      _loadingPosts = true;
    });

    final profile = await AuthService.loadCurrentProfile(forceRefresh: true);
    if (!mounted) return;

    setState(() {
      _profile = profile;
      _loadingProfile = false;
    });

    await _loadPosts(profile);
  }

  Future<void> _loadPosts(UserProfile? profile) async {
    if (profile == null) {
      if (!mounted) return;
      setState(() {
        _myPosts = const [];
        _likedPosts = const [];
        _loadingPosts = false;
      });
      return;
    }

    final results = await Future.wait([
      widget.repository.fetchPostsByAuthorId(profile.id),
      widget.repository.fetchPostsByIds(profile.likedPostIds),
    ]);

    if (!mounted) return;
    setState(() {
      _myPosts = results[0];
      _likedPosts = BlockService.filterPosts(results[1]);
      _loadingPosts = false;
    });
  }

  void _onTabSelected(int index) {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
  }

  Future<void> _openEditProfile() async {
    final updated = await openEditProfileScreen(context);
    if (updated == true && mounted) {
      await _loadAll();
    }
  }

  Future<void> _onFollowTap(CirclePost post) async {
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

  Future<void> _onLikeTap(CirclePost post) async {
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

  Future<void> _onMoreTap(CirclePost post) async {
    final result = await CirclePostMoreSheet.show(
      context,
      post: post,
      repository: widget.repository,
    );
    if (!mounted || result != CirclePostMoreResult.deleted) return;
    setState(() {
      _myPosts = _myPosts.where((p) => p.id != post.id).toList();
      _likedPosts = _likedPosts.where((p) => p.id != post.id).toList();
    });
    ProfileRefreshSignal.notify();
  }

  Future<void> _openPostDetail(CirclePost post) async {
    final isOwnPost = post.authorId == _profile?.id;
    final result = await openCirclePostDetail(
      context,
      post: post,
      isFollowed: isOwnPost || FollowService.isFollowing(post.authorId),
      isLiked: LikeService.isLiked(post.id),
    );
    if (!mounted) return;
    if (result?.deleted == true) {
      setState(() {
        _myPosts = _myPosts.where((p) => p.id != post.id).toList();
        _likedPosts = _likedPosts.where((p) => p.id != post.id).toList();
      });
      ProfileRefreshSignal.notify();
      return;
    }
    if (result != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final displayName = profile?.displayName ?? 'Player';
    final email = profile?.email ?? AuthService.currentUser?.email ?? '';
    final bio = profile?.bio?.trim();
    final handle = formatUserHandle(
      email: email.isNotEmpty ? email : null,
      userId: profile?.id,
    );

    return ColoredBox(
      color: splashBackground,
      child: RefreshIndicator(
        color: const Color(0xFFD14D4D),
        onRefresh: _loadAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileTopSection(
                profile: profile,
                displayName: displayName,
                email: email,
                handle: handle,
                bio: bio,
                tabIndex: _tabIndex,
                onTabSelected: _onTabSelected,
                onSettingsTap: () => openSettingsScreen(context),
                onCoinsStoreTap: () => openCoinsStore(context),
                onEditAvatarTap: _openEditProfile,
              ),
            ),
            if (_loadingProfile || _loadingPosts)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD14D4D),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_visiblePosts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _ProfileEmptyState(),
              )
            else
              CircleFeedVerticalPostList(
                key: ValueKey('profile_posts_$_tabIndex'),
                posts: _visiblePosts,
                followedAuthorIds: FollowService.followedIds.value,
                likedPostIds: LikeService.likedPostIds.value,
                hideFollowForAuthorId: profile?.id,
                onFollowTap: _onFollowTap,
                onLikeTap: _onLikeTap,
                onMoreTap: _onMoreTap,
                onPostTap: _openPostDetail,
              ),
          ],
        ),
      ),
    );
  }
}

/// 顶栏 + 重叠头像 + 资料区（单块布局，避免负 padding / Transform）。
class _ProfileTopSection extends StatelessWidget {
  const _ProfileTopSection({
    required this.profile,
    required this.displayName,
    required this.email,
    required this.handle,
    required this.bio,
    required this.tabIndex,
    required this.onTabSelected,
    required this.onSettingsTap,
    required this.onCoinsStoreTap,
    required this.onEditAvatarTap,
  });

  final UserProfile? profile;
  final String displayName;
  final String email;
  final String handle;
  final String? bio;
  final int tabIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSettingsTap;
  final VoidCallback onCoinsStoreTap;
  final VoidCallback onEditAvatarTap;

  static const _headerH = _ProfileTabState._headerPatternHeight;
  static const _avatarSize = _ProfileTabState._avatarSize;
  static const _avatarOverlap = _ProfileTabState._avatarOverlap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final stackHeight = topInset + _headerH + _avatarSize - _avatarOverlap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: stackHeight,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset + _headerH,
                child: _ProfileHeaderBar(
                  topInset: topInset,
                  onSettingsTap: onSettingsTap,
                ),
              ),
              Positioned(
                bottom: 0,
                child: _ProfileAvatar(
                  profile: profile,
                  onEditAvatarTap: onEditAvatarTap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            height: 1.1,
          ),
        ),
        if (handle != '@user') ...[
          const SizedBox(height: 6),
          Text(
            handle,
            textAlign: TextAlign.center,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _IntroBox(bio: bio),
        const SizedBox(height: 14),
        _CoinsStoreBanner(onTap: onCoinsStoreTap),
        const SizedBox(height: 20),
        ProfileFilterTabs(
          selectedIndex: tabIndex,
          onSelected: onTabSelected,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ProfileHeaderBar extends StatelessWidget {
  const _ProfileHeaderBar({
    required this.topInset,
    required this.onSettingsTap,
  });

  final double topInset;
  final VoidCallback onSettingsTap;

  /// 相对安全区顶部的额外下移（Mine / Settings）。
  static const _contentTopBelowInset = 20.0;

  @override
  Widget build(BuildContext context) {
    final contentTop = topInset + _contentTopBelowInset;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          ProfileAssets.headerBg,
          fit: BoxFit.none,
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
          filterQuality: FilterQuality.medium,
        ),
        Positioned(
          left: 20,
          top: contentTop,
          child: Image.asset(
            ProfileAssets.titleMine,
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          right: 16,
          top: contentTop - 2,
          child: GestureDetector(
            onTap: onSettingsTap,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              ProfileAssets.btnSettings,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.onEditAvatarTap,
  });

  final UserProfile? profile;
  final VoidCallback onEditAvatarTap;

  static const _size = _ProfileTabState._avatarSize;
  /// 编辑头像角标切图逻辑尺寸（@3x 75px → 25pt）。
  static const _editBadgeSize = 25.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _buildAvatarImage()),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: onEditAvatarTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                ProfileAssets.btnEditAvatar,
                width: _editBadgeSize,
                height: _editBadgeSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (profile != null &&
        profile!.avatarUrl != null &&
        profile!.avatarUrl!.isNotEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black, width: 2.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19.5),
          child: CachedMediaImage(
            url: profile!.avatarUrl!,
            cacheKey: profile!.avatarPath,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(),
          ),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black, width: 2.5),
      ),
      child: Icon(
        Icons.person_outline,
        size: _size * 0.42,
        color: Colors.black.withValues(alpha: 0.35),
      ),
    );
  }
}

class _IntroBox extends StatelessWidget {
  const _IntroBox({this.bio});

  final String? bio;

  @override
  Widget build(BuildContext context) {
    final text = bio != null && bio!.isNotEmpty
        ? bio!
        : 'Share a little about yourself.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 2.5),
          image: const DecorationImage(
            image: AssetImage(ProfileAssets.introBoxBg),
            fit: BoxFit.fill,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.65),
            ),
            children: [
              const TextSpan(
                text: 'Intro: ',
                style: TextStyle(
                  color: Color(0xFFC84B4B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(text: text),
            ],
          ),
        ),
      ),
    );
  }
}

/// 无帖子时居中鸡尾酒剪影。
class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState();

  static const _iconSize = 55.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        ProfileAssets.icEmpty,
        width: _iconSize,
        height: _iconSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _CoinsStoreBanner extends StatelessWidget {
  const _CoinsStoreBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Image.asset(
          ProfileAssets.bannerCoinsStore,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

