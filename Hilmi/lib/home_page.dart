import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_service.dart';
import 'core/home_shell.dart';
import 'core/profile_refresh_signal.dart';
import 'core/message_list_refresh_signal.dart';
import 'models/home_models.dart';
import 'screens/circle_feed_screen.dart';
import 'screens/discover_home_tab.dart';
import 'screens/messages_tab.dart';
import 'screens/profile_tab.dart';
import 'splash_page.dart';
import 'utils/open_login_screen.dart';
import 'widgets/app_bottom_tab_bar.dart';
import 'widgets/circle/circle_feed_guide_overlay.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.feed});

  /// 后续从数据库/接口注入；默认使用占位数据。
  final HomeFeedData? feed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;
  bool _showCircleSwipeGuide = false;
  StreamSubscription<AuthState>? _authSubscription;

  static const _circleTabIndex = 1;
  static const _messagesTabIndex = 2;
  static const _profileTabIndex = 3;

  static const _tabAssets = [
    'assets/home/tab_cocktail.png',
    'assets/home/tab_flame.png',
    'assets/home/tab_chat.png',
    'assets/home/tab_bear.png',
  ];

  @override
  void initState() {
    super.initState();
    HomeShell.selectTabHandler = (index) {
      if (!mounted) return;
      unawaited(_onTabSelected(index));
    };
    if (AuthService.isLoggedIn) {
      AuthService.refreshSessionOrSignOut().then((_) {
        if (!mounted) return;
        if (AuthService.isLoggedIn) {
          AuthService.loadCurrentProfile();
        }
        setState(() {});
      });
    }
    _authSubscription = AuthService.onAuthStateChange.listen((_) async {
      if (!mounted) return;
      if (AuthService.isLoggedIn) {
        await AuthService.loadCurrentProfile(forceRefresh: true);
      } else {
        _selectedTab = 0;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    HomeShell.selectTabHandler = null;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onTabSelected(int index) async {
    final requiresLogin =
        index == _messagesTabIndex || index == _profileTabIndex;
    if (requiresLogin && !AuthService.isLoggedIn) {
      if (!await ensureLoggedIn(context, loginHint: 'Please sign in first')) {
        return;
      }
      if (!mounted) return;
    }
    setState(() => _selectedTab = index);
    if (index == _messagesTabIndex && AuthService.isLoggedIn) {
      MessageListRefreshSignal.notify();
    }
    if (index == _profileTabIndex && AuthService.isLoggedIn) {
      ProfileRefreshSignal.notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onProfileTab =
        _selectedTab == _profileTabIndex && AuthService.isLoggedIn;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: onProfileTab
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: splashBackground,
              systemNavigationBarIconBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: splashBackground,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
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
                      index: _selectedTab,
                      children: [
                        DiscoverHomeTab(feed: widget.feed),
                        CircleFeedScreen(
                          isTabActive: _selectedTab == _circleTabIndex,
                          onSwipeGuideChanged: (show) {
                            if (!mounted) return;
                            setState(() => _showCircleSwipeGuide = show);
                          },
                        ),
                        const MessagesTab(),
                        AuthService.isLoggedIn
                            ? const ProfileTab()
                            : const _ShellPlaceholderTab(label: 'Profile'),
                      ],
                    ),
                  ),
                  AppBottomTabBar(
                    selectedIndex: _selectedTab,
                    tabAssets: _tabAssets,
                    onSelected: _onTabSelected,
                  ),
                ],
              ),
            ),
            if (_showCircleSwipeGuide && _selectedTab == _circleTabIndex)
              Positioned.fill(
                child: CircleFeedGuideOverlay(
                  onDismiss: () {
                    if (!mounted) return;
                    setState(() => _showCircleSwipeGuide = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
