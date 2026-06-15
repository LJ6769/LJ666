// 黑名单列表状态与交互逻辑。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';

class BlacklistListController extends GetxController {
  static const designWidth = 375.0;

  final users = <FollowUser>[].obs;
  final loading = true.obs;
  final removingUserId = RxnString();

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
      final loaded = await BlockService.loadBlockedUsers();
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

  Future<void> onRemove(BuildContext context, FollowUser user) async {
    if (removingUserId.value != null) return;
    removingUserId.value = user.id;
    try {
      final stillBlocked = await BlockService.unblock(user.id);
      if (isClosed) return;
      if (!stillBlocked) {
        users.removeWhere((u) => u.id == user.id);
      }
    } catch (error) {
      if (isClosed) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (!isClosed) removingUserId.value = null;
    }
  }
}
