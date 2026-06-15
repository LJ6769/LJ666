// 一对一私信聊天页状态。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/hidden_conversations_service.dart';
import 'package:hilmi/core/message_list_refresh_signal.dart';
import 'package:hilmi/data/message_repository.dart';
import 'package:hilmi/models/direct_chat_message.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/utils/open_direct_video_call.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';

class DirectChatController extends GetxController {
  DirectChatController({
    required this.peer,
    MessageRepository? repository,
  }) : repository = repository ?? const MessageRepository();

  final DirectChatPeer peer;
  final MessageRepository repository;

  final inputController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <DirectChatMessage>[].obs;
  final conversationId = RxnString();
  final loading = true.obs;
  final sending = false.obs;

  String? get myId => AuthService.cachedProfile?.id;

  @override
  void onInit() {
    super.onInit();
    conversationId.value = peer.conversationId;
    unawaited(loadMessages());
  }

  @override
  void onClose() {
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> loadMessages() async {
    loading.value = true;

    conversationId.value ??= await repository.findConversationId(peer.id);

    final id = conversationId.value;
    if (id != null && id.isNotEmpty) {
      final loaded = await repository.fetchChatMessages(id);
      if (!isClosed) {
        messages.assignAll(loaded);
        loading.value = false;
        scrollToBottom();
      }
    } else if (!isClosed) {
      messages.clear();
      loading.value = false;
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> onVideoTap(BuildContext context) {
    return openDirectVideoCall(context, peer: peer);
  }

  Future<void> onMoreTap(BuildContext context) async {
    final result = await CirclePostMoreSheet.showForUser(
      context,
      userId: peer.id,
    );
    if (result == CirclePostMoreResult.blacklisted && !isClosed) {
      Navigator.of(context).pop();
    }
  }

  Future<void> onSend(BuildContext context) async {
    if (sending.value) return;
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    if (!await ensureLoggedIn(
      context,
      loginHint: 'Please sign in to send messages',
    )) {
      return;
    }
    if (isClosed) return;

    sending.value = true;
    dismissKeyboard(context);

    try {
      final message = await repository.sendChatMessage(
        peerId: peer.id,
        body: text,
        conversationId: conversationId.value,
      );
      if (isClosed) return;
      conversationId.value ??= await repository.findConversationId(peer.id);
      await HiddenConversationsService.unhidePeer(peer.id);
      MessageListRefreshSignal.notify();
      inputController.clear();
      messages.add(message);
      sending.value = false;
      scrollToBottom();
    } catch (error) {
      if (isClosed) return;
      sending.value = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static String formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
