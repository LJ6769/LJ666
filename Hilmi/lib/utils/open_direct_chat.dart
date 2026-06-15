// 导航打开一对一私信聊天页。
import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/hidden_conversations_service.dart';
import 'package:hilmi/core/message_list_refresh_signal.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/screens/direct_chat_screen.dart';

Future<void> openDirectChat(
  BuildContext context, {
  required DirectChatPeer peer,
}) async {
  final peerId = peer.id.trim();
  if (peerId.isNotEmpty && AuthService.isLoggedIn) {
    await HiddenConversationsService.unhidePeer(peerId);
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DirectChatScreen(peer: peer),
    ),
  );
  MessageListRefreshSignal.notify();
}
