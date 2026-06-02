/// [HomePage] 底栏切换（退出登录后回到首页 Discover）。
abstract final class HomeShell {
  static void Function(int index)? _selectTab;

  static set selectTabHandler(void Function(int index)? handler) {
    _selectTab = handler;
  }

  static void selectTab(int index) => _selectTab?.call(index);

  static void goToDiscoverHome() => selectTab(0);
}
