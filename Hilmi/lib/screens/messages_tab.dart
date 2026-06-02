import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/hidden_conversations_service.dart';
import 'package:hilmi/core/message_list_refresh_signal.dart';
import 'package:hilmi/data/message_repository.dart';
import 'package:hilmi/models/message_conversation.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/utils/open_direct_chat.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/message/message_list_layout.dart';
import 'package:hilmi/widgets/message/message_list_widgets.dart';

/// 底部导航第三项：私信列表（对齐设计稿）。
class MessagesTab extends StatefulWidget {
  const MessagesTab({
    super.key,
    this.repository = const MessageRepository(),
  });

  final MessageRepository repository;

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  List<MessageFeaturedUser> _featured = const [];
  List<MessageConversation> _allConversations = const [];
  Set<String> _hiddenPeerIds = {};
  String? _revealedConversationId;
  bool _loading = true;
  bool _refreshing = false;
  StreamSubscription<AuthState>? _authSubscription;

  double _scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / MessageListLayout.designWidth;

  @override
  void initState() {
    super.initState();
    BlockService.blockedIds.addListener(_onBlockedChanged);
    HiddenConversationsService.hiddenPeerIds.addListener(_onHiddenPeersChanged);
    MessageListRefreshSignal.notifier.addListener(_onMessageListRefreshSignal);
    _authSubscription = AuthService.onAuthStateChange.listen((_) {
      if (mounted) _load();
    });
    _load();
  }

  @override
  void dispose() {
    BlockService.blockedIds.removeListener(_onBlockedChanged);
    HiddenConversationsService.hiddenPeerIds.removeListener(_onHiddenPeersChanged);
    MessageListRefreshSignal.notifier.removeListener(_onMessageListRefreshSignal);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onHiddenPeersChanged() {
    if (!mounted) return;
    setState(() {
      _hiddenPeerIds = HiddenConversationsService.hiddenPeerIds.value;
    });
  }

  void _onMessageListRefreshSignal() {
    if (!mounted || _loading) return;
    unawaited(_load(isRefresh: true));
  }

  void _onBlockedChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _loading = true);
    }

    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile(
        forceRefresh: isRefresh,
      );
    }

    final results = await Future.wait([
      widget.repository.fetchFeaturedUsers(),
      widget.repository.fetchConversations(),
    ]);

    final hiddenPeers = AuthService.isLoggedIn
        ? await HiddenConversationsService.loadHiddenPeerIds()
        : <String>{};

    if (!mounted) return;
    setState(() {
      _featured = results[0] as List<MessageFeaturedUser>;
      _allConversations = results[1] as List<MessageConversation>;
      _hiddenPeerIds = hiddenPeers;
      _loading = false;
      _refreshing = false;
    });
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _load(isRefresh: true);
  }

  List<MessageConversation> get _visibleConversations {
    return _allConversations
        .where(
          (c) =>
              !_hiddenPeerIds.contains(c.peerId) &&
              !BlockService.isBlocked(c.peerId),
        )
        .toList();
  }

  List<MessageFeaturedUser> get _visibleFeatured {
    final myId = AuthService.cachedProfile?.id;
    return _featured
        .where(
          (u) =>
              u.id != myId && !BlockService.isBlocked(u.id),
        )
        .toList();
  }

  Future<void> _onHideConversation(MessageConversation conversation) async {
    final peerId = conversation.peerId.trim();
    if (peerId.isEmpty) return;

    if (AuthService.isLoggedIn) {
      await HiddenConversationsService.hidePeer(peerId);
    }
    if (!mounted) return;
    setState(() {
      _hiddenPeerIds.add(peerId);
      if (_revealedConversationId == conversation.conversationId) {
        _revealedConversationId = null;
      }
    });
  }

  void _revealConversation(String conversationId) {
    if (_revealedConversationId == conversationId) return;
    setState(() => _revealedConversationId = conversationId);
  }

  void _closeRevealedConversation(String conversationId) {
    if (_revealedConversationId != conversationId) return;
    setState(() => _revealedConversationId = null);
  }

  Future<void> _openChat({
    required String peerId,
    required String peerName,
    String? peerEmail,
    String? peerAvatarUrl,
    String? conversationId,
  }) async {
    if (_revealedConversationId != null) {
      setState(() => _revealedConversationId = null);
    }
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
    }
    await openDirectChat(
      context,
      peer: DirectChatPeer(
        id: peerId,
        name: peerName,
        email: peerEmail,
        avatarUrl: peerAvatarUrl,
        conversationId: conversationId,
      ),
    );
  }

  void _onFeaturedProfileTap(MessageFeaturedUser user) {
    openStarProfileForUser(
      context,
      userId: user.id,
      name: user.name,
      email: user.email,
      imageUrl: user.avatarUrl,
    );
  }

  Future<void> _onFeaturedChatTap(MessageFeaturedUser user) {
    return _openChat(
      peerId: user.id,
      peerName: user.name,
      peerEmail: user.email,
      peerAvatarUrl: user.avatarUrl,
    );
  }

  Future<void> _onConversationTap(MessageConversation conversation) {
    return _openChat(
      peerId: conversation.peerId,
      peerName: conversation.peerName,
      peerEmail: conversation.peerEmail,
      peerAvatarUrl: conversation.peerAvatarUrl,
      conversationId: conversation.conversationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final coins = AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;

    return ColoredBox(
      color: splashBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MessageListHeader(coinBalance: coins),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD14D4D),
                      strokeWidth: 2,
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFFD14D4D),
                    onRefresh: _onRefresh,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final emptyMinH = (constraints.maxHeight -
                                MessageListLayout.featuredRowH -
                                MessageListLayout.allChatH * s -
                                48 * s)
                            .clamp(120.0, double.infinity);

                        return CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            SliverToBoxAdapter(
                              child: MessageFeaturedUsersRow(
                                users: _visibleFeatured,
                                onProfileTap: _onFeaturedProfileTap,
                                onChatTap: _onFeaturedChatTap,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: MessageAllChatChip(scale: s),
                            ),
                            if (_visibleConversations.isEmpty)
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: emptyMinH,
                                  child: MessageListEmptyPlaceholder(
                                    scale: s,
                                  ),
                                ),
                              )
                            else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final conversation = _visibleConversations[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12 * s),
                                  child: MessageConversationTile(
                                    key: ValueKey(conversation.conversationId),
                                    conversation: conversation,
                                    scale: s,
                                    revealed: _revealedConversationId ==
                                        conversation.conversationId,
                                    onReveal: () => _revealConversation(
                                      conversation.conversationId,
                                    ),
                                    onClose: () => _closeRevealedConversation(
                                      conversation.conversationId,
                                    ),
                                    onTap: () =>
                                        _onConversationTap(conversation),
                                    onDelete: () =>
                                        _onHideConversation(conversation),
                                  ),
                                );
                              },
                              childCount: _visibleConversations.length,
                            ),
                          ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: 16 * s),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
