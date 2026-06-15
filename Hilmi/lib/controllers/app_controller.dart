// 应用启动流程：闪屏与新手引导状态。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/app_config.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/core/onboarding_service.dart';

class AppController extends GetxController with WidgetsBindingObserver {
  final showSplash = true.obs;
  final showOnboarding = false.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.delayed(AppConfig.splashDuration, () {
      if (!isClosed) unawaited(onSplashFinished());
    });
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      LiveVideoPreloader.disposeAll();
    }
  }

  Future<void> onSplashFinished() async {
    final completed = await OnboardingService.hasCompletedOnboarding();
    showSplash.value = false;
    showOnboarding.value = !completed;
  }

  void onOnboardingFinished() {
    showOnboarding.value = false;
  }
}
