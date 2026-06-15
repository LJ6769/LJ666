// 底部 Tab：私信会话列表与推荐用户。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/controllers/messages_controller.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/models/message_conversation.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/open_direct_chat.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/message/message_list_layout.dart';
import 'package:hilmi/widgets/message/message_list_widgets.dart';

/// 底部导航第三项：私信列表（对齐设计稿）。
class MessagesTab extends GetView<MessagesController> {
  const MessagesTab({super.key});

  double _scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / MessageListLayout.designWidth;

  Future<void> _onDeleteConversation(
    BuildContext context,
    MessageConversation conversation,
  ) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
    }

    try {
      await controller.deleteConversation(conversation);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete conversation: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await controller.refreshFeed();
    }
  }

  Future<void> _openChat(
    BuildContext context, {
    required String peerId,
    required String peerName,
    String? peerEmail,
    String? peerAvatarUrl,
    String? conversationId,
  }) async {
    controller.clearRevealedConversation();
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

  void _onFeaturedProfileTap(BuildContext context, MessageFeaturedUser user) {
    openStarProfileForUser(
      context,
      userId: user.id,
      name: user.name,
      email: user.email,
      imageUrl: user.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);

    return Obx(() {
      final coins =
          AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;
      final loading = controller.loading.value;
      final visibleFeatured = controller.visibleFeatured;
      final visibleConversations = controller.visibleConversations;
      final revealedId = controller.revealedConversationId.value;

      return ColoredBox(
        color: splashBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MessageListHeader(coinBalance: coins),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD14D4D),
                        strokeWidth: 2,
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFD14D4D),
                      onRefresh: controller.refreshFeed,
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
                                  users: visibleFeatured,
                                  onProfileTap: (user) =>
                                      _onFeaturedProfileTap(context, user),
                                  onChatTap: (user) => _openChat(
                                    context,
                                    peerId: user.id,
                                    peerName: user.name,
                                    peerEmail: user.email,
                                    peerAvatarUrl: user.avatarUrl,
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: MessageAllChatChip(scale: s),
                              ),
                              if (visibleConversations.isEmpty)
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
                                      final conversation =
                                          visibleConversations[index];
                                      return Padding(
                                        padding:
                                            EdgeInsets.only(bottom: 12 * s),
                                        child: MessageConversationTile(
                                          key: ValueKey(
                                            conversation.conversationId,
                                          ),
                                          conversation: conversation,
                                          scale: s,
                                          revealed: revealedId ==
                                              conversation.conversationId,
                                          onReveal: () => controller
                                              .revealConversation(
                                            conversation.conversationId,
                                          ),
                                          onClose: () => controller
                                              .closeRevealedConversation(
                                            conversation.conversationId,
                                          ),
                                          onTap: () => _openChat(
                                            context,
                                            peerId: conversation.peerId,
                                            peerName: conversation.peerName,
                                            peerEmail: conversation.peerEmail,
                                            peerAvatarUrl:
                                                conversation.peerAvatarUrl,
                                            conversationId:
                                                conversation.conversationId,
                                          ),
                                          onDelete: () =>
                                              _onDeleteConversation(
                                            context,
                                            conversation,
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: visibleConversations.length,
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
    });
  }
}
