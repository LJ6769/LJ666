// 我的关注列表状态与交互逻辑。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/open_direct_chat.dart';
import 'package:hilmi/utils/open_direct_video_call.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';

class FollowListController extends GetxController {
  static const designWidth = 375.0;

  final users = <FollowUser>[].obs;
  final loading = true.obs;
  final togglingUserId = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (!AuthService.isLoggedIn) {
      users.clear();
      loading.value = false;
      return;
    }

    loading.value = true;
    try {
      final loaded = await FollowService.loadFollowingUsers();
      if (isClosed) return;
      users.assignAll(loaded);
      loading.value = false;
    } catch (error) {
      if (isClosed) return;
      loading.value = false;
      final ctx = Get.context;
      if (ctx != null) {
        await showAuthNoticeDialog(
          ctx,
          message: messageFromAuthError(error),
        );
      }
    }
  }

  Future<void> onUnfollow(BuildContext context, FollowUser user) async {
    if (togglingUserId.value != null) return;
    togglingUserId.value = user.id;
    try {
      final stillFollowing = await FollowService.toggle(user.id);
      if (isClosed) return;
      if (!stillFollowing) {
        users.removeWhere((u) => u.id == user.id);
      }
    } catch (error) {
      if (isClosed) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (!isClosed) togglingUserId.value = null;
    }
  }

  Future<void> onMessageTap(BuildContext context, FollowUser user) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
    }
    if (isClosed) return;
    await openDirectChat(context, peer: user.toDirectChatPeer());
  }

  Future<void> onVideoTap(BuildContext context, FollowUser user) async {
    await openDirectVideoCall(context, peer: user.toDirectChatPeer());
  }
}
