// 个人中心 Mine：资料与 My Post / My Like 状态。
import 'dart:async';

import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/core/profile_refresh_signal.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileController extends GetxController {
  ProfileController({CircleRepository? repository})
      : repository = repository ?? const CircleRepository();

  final CircleRepository repository;

  final profile = Rxn<UserProfile>();
  final myPosts = <CirclePost>[].obs;
  final likedPosts = <CirclePost>[].obs;
  final loadingProfile = true.obs;
  final loadingPosts = true.obs;
  final tabIndex = 0.obs;

  StreamSubscription<AuthState>? _authSubscription;

  List<CirclePost> get visiblePosts =>
      tabIndex.value == 0 ? myPosts : likedPosts;

  void _setProfileIfChanged(UserProfile? next) {
    final current = profile.value;
    if (identical(current, next)) return;
    if (current != null && next != null && _sameProfileForDisplay(current, next)) {
      return;
    }
    profile.value = next;
  }

  static bool _sameProfileForDisplay(UserProfile a, UserProfile b) {
    return a.id == b.id &&
        a.avatarPath == b.avatarPath &&
        a.avatarUrl == b.avatarUrl &&
        a.displayName == b.displayName &&
        a.bio == b.bio &&
        a.email == b.email;
  }

  @override
  void onInit() {
    super.onInit();
    ProfileRefreshSignal.notifier.addListener(_onProfileRefreshSignal);
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    LikeService.likedPostIds.addListener(_onLikedIdsChanged);
    _authSubscription = AuthService.onAuthStateChange.listen(_onAuthStateChanged);
    hydrateFromLocalCache();
    unawaited(loadAll());
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    ProfileRefreshSignal.notifier.removeListener(_onProfileRefreshSignal);
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    LikeService.likedPostIds.removeListener(_onLikedIdsChanged);
    super.onClose();
  }

  void _onAuthStateChanged(AuthState state) {
    final event = state.event;
    if (event != AuthChangeEvent.signedIn && event != AuthChangeEvent.signedOut) {
      return;
    }
    _resetState();
    if (event == AuthChangeEvent.signedIn) {
      hydrateFromLocalCache();
      unawaited(loadAll());
    }
  }

  void _resetState() {
    profile.value = null;
    myPosts.clear();
    likedPosts.clear();
    loadingProfile.value = true;
    loadingPosts.value = true;
    tabIndex.value = 0;
  }

  void _onProfileRefreshSignal() {
    final event = ProfileRefreshSignal.notifier.value;
    if (event.postsOnly) {
      unawaited(refreshPostsOnly());
    } else {
      unawaited(loadAll(forceRefresh: true));
    }
  }

  void hydrateFromLocalCache() {
    final cachedProfile = AuthService.cachedProfile;
    final userId = cachedProfile?.id.trim() ?? '';
    if (userId.isEmpty) return;

    final cached = FeedDataCache.profilePosts(userId);
    if (cached == null) return;

    _setProfileIfChanged(cachedProfile);
    myPosts.assignAll(cached.myPosts);
    likedPosts.assignAll(BlockService.filterPosts(cached.likedPosts));
    loadingProfile.value = false;
    loadingPosts.value = false;
    unawaited(_refreshLikedPosts());
  }

  void _onBlockedIdsChanged() {
    myPosts.assignAll(
      BlockService.filterPosts(myPosts.toList(growable: false)),
    );
    likedPosts.assignAll(
      BlockService.filterPosts(likedPosts.toList(growable: false)),
    );
    syncPostsCache();
  }

  Future<void> _onLikedIdsChanged() async {
    await _refreshLikedPosts();
  }

  Future<void> _refreshLikedPosts() async {
    final ids = LikeService.likedPostIds.value.toList(growable: false);
    if (ids.isEmpty) {
      if (likedPosts.isNotEmpty) {
        likedPosts.clear();
        syncPostsCache();
      }
      return;
    }

    final posts = await repository.fetchPostsByIds(ids);
    if (isClosed) return;
    likedPosts.assignAll(BlockService.filterPosts(posts));
    syncPostsCache();
  }

  Future<void> refreshPostsOnly() async {
    var currentProfile = profile.value ?? AuthService.cachedProfile;
    currentProfile ??= await AuthService.loadCurrentProfile();
    if (currentProfile == null) {
      await loadAll();
      return;
    }
    _setProfileIfChanged(currentProfile);
    loadingPosts.value = true;
    await loadPosts(currentProfile);
  }

  Future<void> loadAll({bool forceRefresh = false}) async {
    final cachedUserId =
        (profile.value ?? AuthService.cachedProfile)?.id.trim() ?? '';
    if (!forceRefresh && cachedUserId.isNotEmpty) {
      final cached = FeedDataCache.profilePosts(cachedUserId);
      if (cached != null) {
        _setProfileIfChanged(
          profile.value ??
              AuthService.cachedProfile ??
              await AuthService.loadCurrentProfile(),
        );
        myPosts.assignAll(cached.myPosts);
        likedPosts.assignAll(BlockService.filterPosts(cached.likedPosts));
        loadingProfile.value = false;
        loadingPosts.value = false;
        unawaited(_refreshLikedPosts());
        return;
      }
    }

    final showLoading = myPosts.isEmpty && likedPosts.isEmpty;
    if (showLoading) {
      loadingProfile.value = true;
      loadingPosts.value = true;
    }

    _setProfileIfChanged(
      await AuthService.loadCurrentProfile(forceRefresh: forceRefresh),
    );
    loadingProfile.value = false;
    await loadPosts(profile.value);
  }

  Future<void> loadPosts(UserProfile? currentProfile) async {
    if (currentProfile == null) {
      myPosts.clear();
      likedPosts.clear();
      loadingPosts.value = false;
      return;
    }

    final likedIds = LikeService.likedPostIds.value.isNotEmpty
        ? LikeService.likedPostIds.value.toList(growable: false)
        : currentProfile.likedPostIds;

    final results = await Future.wait([
      repository.fetchPostsByAuthorId(currentProfile.id),
      repository.fetchPostsByIds(likedIds),
    ]);

    final filteredLiked = BlockService.filterPosts(results[1]);
    myPosts.assignAll(results[0]);
    likedPosts.assignAll(filteredLiked);
    loadingPosts.value = false;
    FeedDataCache.setProfilePosts(
      currentProfile.id,
      myPosts: results[0],
      likedPosts: filteredLiked,
    );
  }

  void syncPostsCache() {
    final userId = profile.value?.id.trim() ?? '';
    if (userId.isEmpty) return;
    FeedDataCache.patchProfilePosts(
      userId,
      myPosts: myPosts.toList(growable: false),
      likedPosts: likedPosts.toList(growable: false),
    );
  }

  void selectTab(int index) {
    if (tabIndex.value == index) return;
    tabIndex.value = index;
    if (index == 1) {
      unawaited(_refreshLikedPosts());
    }
  }

  Future<void> onProfileEdited() => loadAll(forceRefresh: true);

  void removePost(CirclePost post) {
    myPosts.removeWhere((p) => p.id == post.id);
    likedPosts.removeWhere((p) => p.id == post.id);
    syncPostsCache();
    ProfileRefreshSignal.notify();
  }
}
