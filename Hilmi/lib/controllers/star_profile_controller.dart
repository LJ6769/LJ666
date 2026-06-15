// 明星个人中心：资料、帖子与社交操作。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';

class StarProfileController extends GetxController {
  StarProfileController({
    required this.story,
    UserPublicRepository? repository,
    CircleRepository? circleRepository,
  })  : repository = repository ?? const UserPublicRepository(),
        circleRepository = circleRepository ?? const CircleRepository();

  static const designWidth = 375.0;
  static const headerBackground = Color(0xFFDAEBDC);
  static const pageBackground = Color(0xFFEFFEF1);

  final ProfileStory story;
  final UserPublicRepository repository;
  final CircleRepository circleRepository;

  final profile = Rxn<StarPublicProfile>();
  final posts = <CirclePost>[].obs;
  final loading = true.obs;
  final socialRevision = 0.obs;

  double scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  DirectChatPeer get peer {
    final p = profile.value;
    final name = p?.displayName ?? story.name ?? 'User';
    return DirectChatPeer(
      id: story.id,
      name: name,
      email: p?.email ?? story.email,
      avatarUrl: p?.avatarUrl ?? story.imageUrl,
    );
  }

  bool get isFollowing => FollowService.isFollowing(story.id);

  bool get isSelf =>
      AuthService.cachedProfile?.id.trim() == story.id.trim();

  @override
  void onInit() {
    super.onInit();
    FollowService.followedIds.addListener(_onSocialStateChanged);
    LikeService.likedPostIds.addListener(_onSocialStateChanged);
    unawaited(load());
  }

  @override
  void onClose() {
    FollowService.followedIds.removeListener(_onSocialStateChanged);
    LikeService.likedPostIds.removeListener(_onSocialStateChanged);
    super.onClose();
  }

  void _onSocialStateChanged() {
    if (!isClosed) socialRevision.value++;
  }

  Future<void> onPostFollowTap(BuildContext context, CirclePost post) async {
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

  Future<void> onPostLikeTap(BuildContext context, CirclePost post) async {
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

  Future<void> onPostMoreTap(BuildContext context, CirclePost post) async {
    final result = await CirclePostMoreSheet.show(
      context,
      post: post,
      repository: circleRepository,
    );
    if (result != CirclePostMoreResult.deleted) return;
    posts.removeWhere((p) => p.id == post.id);
  }

  Future<void> load() async {
    final results = await Future.wait<dynamic>([
      repository.fetchProfile(story.id),
      circleRepository.fetchPostsByAuthorId(story.id),
    ]);
    if (isClosed) return;
    final loadedPosts = results[1] as List<CirclePost>;
    profile.value = results[0] as StarPublicProfile?;
    posts.assignAll(BlockService.filterPosts(loadedPosts));
    loading.value = false;
  }

  Future<void> openPostDetail(BuildContext context, CirclePost post) async {
    final result = await openCirclePostDetail(
      context,
      post: post,
      isFollowed: FollowService.isFollowing(post.authorId),
      isLiked: LikeService.isLiked(post.id),
    );
    if (result != null && !isClosed) socialRevision.value++;
  }

  Future<void> onChatTap(BuildContext context) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
    }
    if (!context.mounted) return;
    await openDirectChat(context, peer: peer);
  }

  Future<void> onVideoCallTap(BuildContext context) async {
    await openDirectVideoCall(context, peer: peer);
  }

  Future<void> onMoreTap(BuildContext context) async {
    final result = await CirclePostMoreSheet.showForUser(
      context,
      userId: story.id,
    );
    if (result == CirclePostMoreResult.blacklisted && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
