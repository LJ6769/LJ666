// 登录后主壳：底部四 Tab（Discover / Circle / 消息 / 我的）与登录态监听。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/home_shell_controller.dart';
import 'package:hilmi/core/app_system_ui.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/screens/circle_feed_screen.dart';
import 'package:hilmi/screens/discover_home_tab.dart';
import 'package:hilmi/screens/messages_tab.dart';
import 'package:hilmi/screens/profile_tab.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/app_bottom_tab_bar.dart';
import 'package:hilmi/widgets/circle/circle_feed_guide_overlay.dart';

class HomePage extends GetView<HomeShellController> {
  const HomePage({super.key, this.feed});

  /// 后续从数据库/接口注入；默认使用占位数据。
  final HomeFeedData? feed;

  static const _tabAssets = [
    'assets/home/tab_cocktail.png',
    'assets/home/tab_flame.png',
    'assets/home/tab_chat.png',
    'assets/home/tab_bear.png',
  ];

  static const _tabAssetsOff = [
    'assets/home/tab_cocktail_off.png',
    'assets/home/tab_flame_off.png',
    'assets/home/tab_chat_off.png',
    'assets/home/tab_bear_off.png',
  ];

  Future<void> _onTabSelected(BuildContext context, int index) async {
    final requiresLogin = index == HomeShellController.messagesTabIndex ||
        index == HomeShellController.profileTabIndex;
    if (requiresLogin && !AuthService.isLoggedIn) {
      if (!await ensureLoggedIn(context, loginHint: 'Please sign in first')) {
        return;
      }
    }
    await controller.selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedTab = controller.selectedTab.value;
      final isLoggedIn = controller.isLoggedIn.value;
      final showCircleSwipeGuide = controller.showCircleSwipeGuide.value;
      final onProfileTab =
          selectedTab == HomeShellController.profileTabIndex && isLoggedIn;

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppSystemUi.lightBackground,
        child: Scaffold(
          backgroundColor: splashBackground,
          body: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                top: !onProfileTab,
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: IndexedStack(
                        index: selectedTab,
                        children: [
                          DiscoverHomeTab(feed: feed),
                          const CircleFeedScreen(),
                          const MessagesTab(),
                          isLoggedIn
                              ? const ProfileTab()
                              : const _ShellPlaceholderTab(label: 'Profile'),
                        ],
                      ),
                    ),
                    AppBottomTabBar(
                      selectedIndex: selectedTab,
                      tabAssets: _tabAssets,
                      tabAssetsOff: _tabAssetsOff,
                      onSelected: (index) => _onTabSelected(context, index),
                    ),
                  ],
                ),
              ),
              if (showCircleSwipeGuide &&
                  selectedTab == HomeShellController.circleTabIndex)
                Positioned.fill(
                  child: CircleFeedGuideOverlay(
                    onDismiss: controller.dismissCircleSwipeGuide,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _ShellPlaceholderTab extends StatelessWidget {
  const _ShellPlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: splashBackground,
      child: Center(
        child: Text(
          '$label — coming soon',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
