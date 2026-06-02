import 'package:flutter/material.dart';

/// 收起软键盘（点击空白区域或输入框外部时调用）。
void dismissKeyboard([BuildContext? context]) {
  FocusManager.instance.primaryFocus?.unfocus();
  if (context != null) {
    final scope = FocusScope.of(context);
    if (scope.focusedChild != null) {
      scope.unfocus();
    }
  }
}

/// 点击非交互区域时收起键盘。
class KeyboardDismissScope extends StatelessWidget {
  const KeyboardDismissScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => dismissKeyboard(context),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
