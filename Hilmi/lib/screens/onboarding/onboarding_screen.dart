// 首次安装多页引导，完成后进入首页。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/constants/guide_assets.dart';
import 'package:hilmi/controllers/onboarding_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';

/// 首次安装引导流程：页 1 → 页 2 → 首页（仅展示一次）。
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return GetxScreen<OnboardingController>(
      create: () => OnboardingController(onFinished: onFinished),
      builder: (c) => Obx(() {
        final page = c.currentPage;
        final scale =
            MediaQuery.sizeOf(context).width / OnboardingController.designWidth;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final statusBrightness = page.statusBarStyle;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: statusBrightness,
            statusBarBrightness: statusBrightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: page.fallbackColor,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    page.backgroundAsset,
                    fit: BoxFit.fill,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  left: 40 * scale,
                  right: 40 * scale,
                  bottom: 24 * scale + bottomInset,
                  child: GestureDetector(
                    onTap: c.onNextTap,
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      GuideAssets.btnNext,
                      fit: BoxFit.fitWidth,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
