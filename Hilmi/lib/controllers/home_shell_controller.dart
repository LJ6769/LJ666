// 主壳底栏 Tab、登录态与 Circle 引导层状态。
import 'dart:async';

import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/home_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeShellController extends GetxController {
  static const circleTabIndex = 1;
  static const messagesTabIndex = 2;
  static const profileTabIndex = 3;

  final selectedTab = 0.obs;
  final showCircleSwipeGuide = false.obs;
  final isLoggedIn = false.obs;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    HomeShell.selectTabHandler = selectTab;
    isLoggedIn.value = AuthService.isLoggedIn;
    _bootstrapAuth();
    _authSubscription = AuthService.onAuthStateChange.listen(_onAuthStateChanged);
  }

  void _bootstrapAuth() {
    if (!AuthService.isLoggedIn) return;
    AuthService.refreshSessionOrSignOut().then((_) {
      if (!AuthService.isLoggedIn) {
        isLoggedIn.value = false;
        return;
      }
      AuthService.loadCurrentProfile();
      isLoggedIn.value = true;
    });
  }

  Future<void> _onAuthStateChanged(AuthState _) async {
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    } else {
      selectedTab.value = 0;
    }
    isLoggedIn.value = AuthService.isLoggedIn;
  }

  Future<bool> selectTab(int index) async {
    selectedTab.value = index;
    return true;
  }

  void setCircleSwipeGuide(bool show) {
    showCircleSwipeGuide.value = show;
  }

  void dismissCircleSwipeGuide() {
    showCircleSwipeGuide.value = false;
  }

  @override
  void onClose() {
    HomeShell.selectTabHandler = null;
    _authSubscription?.cancel();
    super.onClose();
  }
}
