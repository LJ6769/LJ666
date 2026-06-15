// 我的粉丝列表状态与交互逻辑。
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

class FollowersListController extends GetxController {
  static const designWidth = 375.0;

  final users = <FollowUser>[].obs;
  final loading = true.obs;
  final togglingUserId = RxnString();
  final followIdsVersion = 0.obs;

  @override
  void onInit() {
    super.onInit();
    FollowService.followedIds.addListener(_onFollowIdsChanged);
    load();
  }

  @override
  void onClose() {
    FollowService.followedIds.removeListener(_onFollowIdsChanged);
    super.onClose();
  }

  void _onFollowIdsChanged() {
    followIdsVersion.value++;
  }

  Future<void> load() async {
    if (!AuthService.isLoggedIn) {
      users.clear();
      loading.value = false;
      return;
    }

    loading.value = true;
    try {
      final loaded = await FollowService.loadFollowerUsers();
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

  Future<void> onFollowTap(BuildContext context, FollowUser user) async {
    if (togglingUserId.value != null) return;
    togglingUserId.value = user.id;
    try {
      await FollowService.toggle(user.id);
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
