// 导航打开私信视频通话等待页。
import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/screens/direct_video_call_screen.dart';
import 'package:hilmi/utils/open_login_screen.dart';

/// 视频通话页：自底部滑入/滑出（非左右 push）。
class _VideoCallSlideUpRoute<T> extends PageRouteBuilder<T> {
  _VideoCallSlideUpRoute({required WidgetBuilder builder})
      : super(
          opaque: true,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );
            return SlideTransition(position: slide, child: child);
          },
        );
}

Future<void> openDirectVideoCall(
  BuildContext context, {
  required DirectChatPeer peer,
}) async {
  if (!AuthService.isLoggedIn) {
    await openLoginScreen(context);
    return;
  }
  await Navigator.of(context).push<void>(
    _VideoCallSlideUpRoute<void>(
      builder: (_) => DirectVideoCallScreen(peer: peer),
    ),
  );
}
