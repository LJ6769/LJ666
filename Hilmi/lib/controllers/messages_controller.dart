// 消息 Tab：推荐用户与会话列表状态。
import 'dart:async';

import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/core/hidden_conversations_service.dart';
import 'package:hilmi/core/message_list_refresh_signal.dart';
import 'package:hilmi/data/message_repository.dart';
import 'package:hilmi/models/message_conversation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesController extends GetxController {
  MessagesController({MessageRepository? repository})
      : repository = repository ?? const MessageRepository();

  final MessageRepository repository;

  final featured = <MessageFeaturedUser>[].obs;
  final allConversations = <MessageConversation>[].obs;
  final hiddenPeerIds = <String>{}.obs;
  final revealedConversationId = RxnString();
  final loading = true.obs;
  final refreshing = false.obs;

  StreamSubscription<AuthState>? _authSubscription;
  int _loadGeneration = 0;

  List<MessageConversation> get visibleConversations {
    return allConversations
        .where(
          (c) =>
              !hiddenPeerIds.contains(c.peerId) &&
              !BlockService.isBlocked(c.peerId),
        )
        .toList();
  }

  List<MessageFeaturedUser> get visibleFeatured {
    final myId = AuthService.cachedProfile?.id;
    return featured
        .where((u) => u.id != myId && !BlockService.isBlocked(u.id))
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    BlockService.blockedIds.addListener(_onBlockedChanged);
    HiddenConversationsService.hiddenPeerIds
        .addListener(_onHiddenPeersChanged);
    MessageListRefreshSignal.notifier.addListener(_onMessageListRefreshSignal);
    _authSubscription = AuthService.onAuthStateChange.listen(_onAuthStateChanged);
    unawaited(load());
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    BlockService.blockedIds.removeListener(_onBlockedChanged);
    HiddenConversationsService.hiddenPeerIds
        .removeListener(_onHiddenPeersChanged);
    MessageListRefreshSignal.notifier.removeListener(_onMessageListRefreshSignal);
    super.onClose();
  }

  void _onAuthStateChanged(AuthState state) {
    final event = state.event;
    if (event != AuthChangeEvent.signedIn && event != AuthChangeEvent.signedOut) {
      return;
    }
    _resetState();
    if (event == AuthChangeEvent.signedIn) {
      unawaited(load());
    }
  }

  void _resetState() {
    featured.clear();
    allConversations.clear();
    hiddenPeerIds.clear();
    revealedConversationId.value = null;
    loading.value = true;
    refreshing.value = false;
  }

  void _onHiddenPeersChanged() {
    hiddenPeerIds.assignAll(HiddenConversationsService.hiddenPeerIds.value);
  }

  void _onMessageListRefreshSignal() {
    if (loading.value) return;
    unawaited(refreshFeed());
  }

  void _onBlockedChanged() {
    _reconcileFeaturedUsers();
    allConversations.refresh();
  }

  void _reconcileFeaturedUsers() {
    final current = featured.toList(growable: false);

    final pool = FeedDataCache.messageFeaturedPool;
    if (pool == null) {
      featured.removeWhere(
        (user) => BlockService.isBlocked(user.id),
      );
      return;
    }

    final refilled = MessageRepository.refillFeaturedAfterBlock(
      current: current,
      pool: pool,
      blockedIds: BlockService.blockedIds.value,
      myId: AuthService.cachedProfile?.id,
    );
    featured.assignAll(refilled);
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (!forceRefresh && (featured.isNotEmpty || allConversations.isNotEmpty)) {
      loading.value = false;
      return;
    }

    final generation = ++_loadGeneration;

    if (!forceRefresh) {
      loading.value = true;
    }

    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile(forceRefresh: forceRefresh);
    }

    final results = await Future.wait([
      repository.fetchFeaturedUsers(
        blockedIds: BlockService.blockedIds.value,
        forceNetwork: forceRefresh,
      ),
      repository.fetchConversations(),
    ]);

    if (generation != _loadGeneration) return;

    final hiddenPeers = AuthService.isLoggedIn
        ? await HiddenConversationsService.loadHiddenPeerIds()
        : <String>{};

    if (generation != _loadGeneration) return;

    featured.assignAll(results[0] as List<MessageFeaturedUser>);
    allConversations.assignAll(results[1] as List<MessageConversation>);
    hiddenPeerIds.assignAll(hiddenPeers);
    _reconcileFeaturedUsers();
    loading.value = false;
    refreshing.value = false;
  }

  Future<void> refreshFeed() async {
    if (refreshing.value) return;
    refreshing.value = true;

    final generation = ++_loadGeneration;

    final localFeatured = MessageRepository.reshuffleFeaturedFromLocalPool(
      blockedIds: BlockService.blockedIds.value,
    );
    if (localFeatured.isNotEmpty) {
      featured.assignAll(localFeatured);
    } else {
      featured.assignAll(
        await repository.fetchFeaturedUsers(
          blockedIds: BlockService.blockedIds.value,
        ),
      );
    }

    if (generation != _loadGeneration) {
      refreshing.value = false;
      return;
    }

    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }

    allConversations.assignAll(await repository.fetchConversations());

    if (generation != _loadGeneration) {
      refreshing.value = false;
      return;
    }

    final hiddenPeers = AuthService.isLoggedIn
        ? await HiddenConversationsService.loadHiddenPeerIds()
        : <String>{};
    hiddenPeerIds.assignAll(hiddenPeers);
    refreshing.value = false;
  }

  void revealConversation(String conversationId) {
    if (revealedConversationId.value == conversationId) return;
    revealedConversationId.value = conversationId;
  }

  void closeRevealedConversation(String conversationId) {
    if (revealedConversationId.value != conversationId) return;
    revealedConversationId.value = null;
  }

  void clearRevealedConversation() {
    revealedConversationId.value = null;
  }

  void optimisticallyRemoveConversation(MessageConversation conversation) {
    final conversationId = conversation.conversationId.trim();
    final peerId = conversation.peerId.trim();
    allConversations.removeWhere((c) => c.conversationId == conversationId);
    hiddenPeerIds.remove(peerId);
    if (revealedConversationId.value == conversation.conversationId) {
      revealedConversationId.value = null;
    }
  }

  Future<void> deleteConversation(MessageConversation conversation) async {
    final conversationId = conversation.conversationId.trim();
    final peerId = conversation.peerId.trim();
    if (conversationId.isEmpty) return;

    optimisticallyRemoveConversation(conversation);
    await repository.deleteConversation(conversationId);
    await HiddenConversationsService.unhidePeer(peerId);
    MessageListRefreshSignal.notify();
  }
}
