import 'package:flutter/material.dart';
import 'package:hilmi/widgets/auth/auth_legal_footer.dart';
import 'package:hilmi/widgets/auth/login_layout.dart';

/// 登录/注册页底部：主按钮位置固定，协议区在按钮下方（键盘弹出时仅隐藏协议，按钮不跳动）。
abstract final class AuthFixedFooterLayout {
  /// 主按钮（Next / Sign up）底边距屏幕底部的距离（恒定）。
  static double primaryButtonBottom({
    required double scale,
    required double safeBottomInset,
  }) {
    return LoginLayout.authFixedButtonBottom(
          scale: scale,
          safeBottomInset: safeBottomInset,
        ) +
        (LoginLayout.signInToLegalGap + LoginLayout.legalBlockH) * scale;
  }

  /// 协议区底边距屏幕底部的距离。
  static double legalBottom({
    required double scale,
    required double safeBottomInset,
  }) =>
      LoginLayout.authFixedButtonBottom(
        scale: scale,
        safeBottomInset: safeBottomInset,
      );

  /// 滚动区与底栏之间的总高度（含主按钮 + 协议区）。
  static double totalFooterHeight({required double scale}) =>
      (LoginLayout.signInH +
              LoginLayout.signInToLegalGap +
              LoginLayout.legalBlockH) *
          scale;
}

/// 在父级 [Stack] 中追加固定底栏（勿再包一层 [Positioned.fill] + 内嵌 [Stack]）。
abstract final class AuthFixedFooterLayers {
  static List<Widget> build({
    required double scale,
    required double safeBottomInset,
    required bool keyboardVisible,
    required Widget actionRow,
  }) {
    final primaryBottom = AuthFixedFooterLayout.primaryButtonBottom(
      scale: scale,
      safeBottomInset: safeBottomInset,
    );
    final legalBottom = AuthFixedFooterLayout.legalBottom(
      scale: scale,
      safeBottomInset: safeBottomInset,
    );

    return [
      Positioned(
        left: 0,
        right: 0,
        bottom: primaryBottom,
        child: actionRow,
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: legalBottom,
        child: IgnorePointer(
          ignoring: keyboardVisible,
          child: Opacity(
            opacity: keyboardVisible ? 0 : 1,
            child: AuthLegalFooter(scale: scale),
          ),
        ),
      ),
    ];
  }
}
