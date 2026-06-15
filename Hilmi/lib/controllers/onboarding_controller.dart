// 首次安装多页引导状态与翻页逻辑。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/constants/guide_assets.dart';
import 'package:hilmi/core/onboarding_service.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.backgroundAsset,
    required this.fallbackColor,
    required this.statusBarStyle,
  });

  final String backgroundAsset;
  final Color fallbackColor;
  final Brightness statusBarStyle;
}

class OnboardingController extends GetxController {
  OnboardingController({required this.onFinished});

  static const designWidth = 375.0;

  final VoidCallback onFinished;

  final pageIndex = 0.obs;

  static const pages = <OnboardingPageData>[
    OnboardingPageData(
      backgroundAsset: GuideAssets.page1Background,
      fallbackColor: Color(0xFFE63946),
      statusBarStyle: Brightness.light,
    ),
    OnboardingPageData(
      backgroundAsset: GuideAssets.page2Background,
      fallbackColor: Color(0xFFF5B84A),
      statusBarStyle: Brightness.dark,
    ),
  ];

  OnboardingPageData get currentPage => pages[pageIndex.value];

  Future<void> onNextTap() async {
    if (pageIndex.value < pages.length - 1) {
      pageIndex.value++;
      return;
    }
    await OnboardingService.markOnboardingCompleted();
    onFinished();
  }
}
