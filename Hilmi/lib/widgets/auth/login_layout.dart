/// 登录页布局常量（切图为 @3x，数值 = 像素 ÷ 3，再乘 width/375 缩放）。
abstract final class LoginLayout {
  static const designWidth = 375.0;

  static const sheetTop = 248.0;

  static const backSize = 35.0;
  static const backLeft = 16.0;
  static const backTopBelowSafe = 6.0;

  static const signUpW = 105.0;
  static const signUpH = 36.0;
  static const signUpRight = 16.0;
  static const signUpTopBelowSafe = 8.0;

  static const mascotW = 100.0;
  static const mascotH = 137.0;
  static const mascotLeft = 10.0;
  /// 杯底三角座探入奶油区（对齐设计稿：仅底座一半在下方）
  static const mascotIntoSheet = 16.0;

  static const titleW = 169.0;
  static const titleH = 56.0;
  static const titleLeft = 118.0;
  static const titleTop = 150.0;

  /// Email / Password 标签切图逻辑高度（@3x 75px → 25pt）
  static const labelH = 25.0;
  static const fieldH = 51.0;
  static const signInH = 51.0;
  /// Sign in 与底部协议文案间距
  static const signInToLegalGap = 16.0;
  static const formPadBottom = 60.0;
  static const appleW = 49.0;
  static const appleH = 51.0;
  static const eyeSize = 15.0;

  static const formPadH = 20.0;
  static const formPadTop = 44.0;
  /// 底部协议区预估高度（用于给滚动区留白）
  static const legalBlockH = 36.0;

  /// 注册第二步：头像占位区（设计稿约 100pt）
  static const avatarSize = 100.0;
  static const avatarCameraSize = 36.0;
  static const introFieldH = 120.0;

  /// 底部红色主按钮固定位置（不随键盘变化）。
  ///
  /// [safeBottomInset] 请传 [MediaQuery.viewPaddingOf] 的 bottom，
  /// 不要用 [MediaQuery.paddingOf]（键盘弹出时 padding.bottom 会变 0，按钮会跳动）。
  static double authFixedButtonBottom({
    required double scale,
    required double safeBottomInset,
  }) =>
      formPadBottom * scale + safeBottomInset;

  /// 表单滚动区距屏幕底部的距离：键盘弹出时止于键盘上方，否则止于固定底栏上方。
  static double authFormScrollAreaBottom({
    required double scale,
    required double keyboardInset,
    required double fixedBottomBlockHeight,
    required double fixedButtonBottom,
  }) {
    if (keyboardInset <= 0) {
      return fixedBottomBlockHeight + fixedButtonBottom;
    }
    return keyboardInset + 8 * scale;
  }

  /// 输入框聚焦滚动留白（保持较小，避免中间大块空白）。
  static double authFieldScrollPadding({required double scale}) => 20 * scale;
}
