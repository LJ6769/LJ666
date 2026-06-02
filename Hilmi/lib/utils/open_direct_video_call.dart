import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/screens/direct_video_call_screen.dart';
import 'package:hilmi/utils/open_login_screen.dart';

Future<void> openDirectVideoCall(
  BuildContext context, {
  required DirectChatPeer peer,
}) async {
  if (!AuthService.isLoggedIn) {
    await openLoginScreen(context);
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DirectVideoCallScreen(peer: peer),
    ),
  );
}
