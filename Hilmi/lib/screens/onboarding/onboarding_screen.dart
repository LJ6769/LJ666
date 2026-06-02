import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/constants/guide_assets.dart';
import 'package:hilmi/core/onboarding_service.dart';

/// 首次安装引导流程：页 1 → 页 2 → 首页（仅展示一次）。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _designWidth = 375.0;

  int _pageIndex = 0;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      backgroundAsset: GuideAssets.page1Background,
      fallbackColor: Color(0xFFE63946),
      statusBarStyle: Brightness.light,
    ),
    _OnboardingPageData(
      backgroundAsset: GuideAssets.page2Background,
      fallbackColor: Color(0xFFF5B84A),
      statusBarStyle: Brightness.dark,
    ),
  ];

  Future<void> _onNextTap() async {
    if (_pageIndex < _pages.length - 1) {
      setState(() => _pageIndex++);
      return;
    }
    await OnboardingService.markOnboardingCompleted();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_pageIndex];
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
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
                onTap: _onNextTap,
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
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.backgroundAsset,
    required this.fallbackColor,
    required this.statusBarStyle,
  });

  final String backgroundAsset;
  final Color fallbackColor;
  final Brightness statusBarStyle;
}
