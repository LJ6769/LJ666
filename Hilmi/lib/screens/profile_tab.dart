// 底部 Tab：个人中心 Mine（资料、My Post、My Like）。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/profile_controller.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/open_circle_post.dart';
import 'package:hilmi/utils/open_coins_store.dart';
import 'package:hilmi/utils/open_edit_profile.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/open_settings_screen.dart';
import 'package:hilmi/utils/user_handle.dart';
import 'package:hilmi/widgets/circle/circle_feed_vertical_post_list.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/profile/profile_assets.dart';
import 'package:hilmi/widgets/profile/profile_filter_tabs.dart';

const _profileHeaderPatternHeight = 168.0;
const _profileAvatarSize = 108.0;
const _profileAvatarOverlap = 54.0;

/// 个人中心（Mine）：资料区 + My Post / My Like 朋友圈式卡片列表。
class ProfileTab extends GetView<ProfileController> {
  const ProfileTab({super.key});

  Future<void> _openEditProfile(BuildContext context) async {
    final updated = await openEditProfileScreen(context);
    if (updated == true) {
      await controller.onProfileEdited();
    }
  }

  Future<void> _onFollowTap(BuildContext context, CirclePost post) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
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
      return;
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
    if (result != CirclePostMoreResult.deleted) return;
    controller.removePost(post);
  }

  Future<void> _openPostDetail(BuildContext context, CirclePost post) async {
    final currentProfile = controller.profile.value;
    final isOwnPost = post.authorId == currentProfile?.id;
    final result = await openCirclePostDetail(
      context,
      post: post,
      isFollowed: isOwnPost || FollowService.isFollowing(post.authorId),
      isLiked: LikeService.isLiked(post.id),
    );
    if (result?.deleted == true) {
      controller.removePost(post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: splashBackground,
      child: RefreshIndicator(
        color: const Color(0xFFD14D4D),
        onRefresh: () => controller.loadAll(forceRefresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Obx(() {
                final currentProfile = controller.profile.value;
                final displayName = currentProfile?.displayName ?? 'Player';
                final email =
                    currentProfile?.email ??
                    AuthService.currentUser?.email ??
                    '';
                final bio = currentProfile?.bio?.trim();
                final handle = formatUserHandle(
                  email: email.isNotEmpty ? email : null,
                  userId: currentProfile?.id,
                );

                return _ProfileTopSection(
                  profile: currentProfile,
                  displayName: displayName,
                  email: email,
                  handle: handle,
                  bio: bio,
                  tabIndex: controller.tabIndex.value,
                  onTabSelected: controller.selectTab,
                  onSettingsTap: () => openSettingsScreen(context),
                  onCoinsStoreTap: () => openCoinsStore(context),
                  onEditAvatarTap: () => _openEditProfile(context),
                );
              }),
            ),
            Obx(() {
              final currentProfile = controller.profile.value;
              final loading = controller.loadingProfile.value ||
                  controller.loadingPosts.value;
              final tabIndex = controller.tabIndex.value;
              final visiblePosts = tabIndex == 0
                  ? controller.myPosts.toList(growable: false)
                  : controller.likedPosts.toList(growable: false);

              if (loading) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD14D4D),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              if (visiblePosts.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ProfileEmptyState(),
                );
              }
              return ValueListenableBuilder<Set<String>>(
                valueListenable: FollowService.followedIds,
                builder: (context, followedIds, _) {
                  return ValueListenableBuilder<Set<String>>(
                    valueListenable: LikeService.likedPostIds,
                    builder: (context, likedPostIds, _) {
                      return CircleFeedVerticalPostList(
                        key: ValueKey('profile_posts_$tabIndex'),
                        posts: visiblePosts,
                        followedAuthorIds: followedIds,
                        likedPostIds: likedPostIds,
                        hideFollowForAuthorId: currentProfile?.id,
                        onFollowTap: (post) => _onFollowTap(context, post),
                        onLikeTap: (post) => _onLikeTap(context, post),
                        onMoreTap: (post) => _onMoreTap(context, post),
                        onPostTap: (post) => _openPostDetail(context, post),
                      );
                    },
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final stackHeight =
        topInset + _profileHeaderPatternHeight + _profileAvatarSize -
            _profileAvatarOverlap;

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
                height: topInset + _profileHeaderPatternHeight,
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

  static const _editBadgeSize = 25.0;

  @override
  Widget build(BuildContext context) {
    final avatarKey = profile?.avatarPath?.trim().isNotEmpty == true
        ? profile!.avatarPath!.trim()
        : profile?.id ?? 'guest';

    return RepaintBoundary(
      child: SizedBox(
        width: _profileAvatarSize,
        height: _profileAvatarSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              key: ValueKey('profile_avatar_$avatarKey'),
              child: _buildAvatarImage(),
            ),
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
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (profile != null &&
        profile!.avatarUrl != null &&
        profile!.avatarUrl!.isNotEmpty) {
      final avatarUrl = profile!.avatarUrl!;
      final avatarPath = profile!.avatarPath;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black, width: 2.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19.5),
          child: CachedMediaImage(
            key: ValueKey(
              avatarPath?.trim().isNotEmpty == true
                  ? avatarPath!.trim()
                  : avatarUrl,
            ),
            url: avatarUrl,
            cacheKey: avatarPath,
            width: _profileAvatarSize,
            height: _profileAvatarSize,
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
        size: _profileAvatarSize * 0.42,
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
