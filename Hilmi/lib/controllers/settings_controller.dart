// 设置页：关注、黑名单、协议、反馈、登出。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/home_shell.dart';
import 'package:hilmi/core/local_cache_service.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/logout_and_go_home.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/settings/settings_assets.dart';

class SettingsController extends GetxController {
  static const appVersionLabel = 'V1.0.0';

  final cacheSizeLabel = '—'.obs;
  final clearingCache = false.obs;
  final loggingOut = false.obs;
  final deletingAccount = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshCacheSize();
  }

  Future<void> refreshCacheSize() async {
    final bytes = await LocalCacheService.estimateCacheBytes();
    cacheSizeLabel.value = LocalCacheService.formatCacheSize(bytes);
  }

  Future<void> onClearCache(BuildContext context) async {
    if (clearingCache.value) return;
    clearingCache.value = true;
    try {
      await LocalCacheService.clearAll();
      await refreshCacheSize();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (context.mounted) clearingCache.value = false;
    }
  }

  Future<void> onDeleteAccount(BuildContext context) async {
    if (deletingAccount.value) return;

    final confirmed = await showAuthConfirmDialog(
      context,
      title: 'Delete Account',
      message:
          'Deleting your account will erase all your data and information '
          'and cannot be undone. Confirm deletion?',
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
      confirmBackgroundAsset: SettingsAssets.btnConfirm,
      cancelBackgroundAsset: SettingsAssets.btnCancel,
      barrierDismissible: false,
      actionButtonHeight: 40,
    );
    if (!confirmed || !context.mounted) return;

    deletingAccount.value = true;
    try {
      await AuthService.deleteAccount();
      await LocalCacheService.clearAll();
      if (!context.mounted) return;
      HomeShell.goToDiscoverHome();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (context.mounted) deletingAccount.value = false;
    }
  }

  Future<void> onLogout(BuildContext context) async {
    if (loggingOut.value) return;

    final confirmed = await showAuthConfirmDialog(
      context,
      title: 'Log out',
      message:
          'After logging out, you will need to log in again to use your account again. Are you sure to log out?',
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
      confirmBackgroundAsset: SettingsAssets.btnConfirm,
      cancelBackgroundAsset: SettingsAssets.btnCancel,
      barrierDismissible: false,
      actionButtonHeight: 40,
    );
    if (!confirmed || !context.mounted) return;

    loggingOut.value = true;
    try {
      await logoutAndGoHome(context);
    } catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (context.mounted) loggingOut.value = false;
    }
  }
}
