abstract final class DirectChatLayout {
  static const designWidth = 375.0;

  static const borderWidth = 3.0;
  static const headerH = 56.0;
  static const headerProfileH = 44.0;
  /// 顶栏资料胶囊宽度（@375 设计宽）。
  static const headerProfileMaxW = 140.0;
  static const inputBarH = 51.0;
  static const messageAvatar = 28.0;

  /// bubble_out / input_field_bg @3x 1005×111
  static const capsuleWidthPx = 1005.0;
  static const capsuleHeightPx = 111.0;
  static const capsuleLogicalH = capsuleHeightPx / 3;
  static const capsuleAspect = capsuleHeightPx / capsuleWidthPx;

  /// 与 bubble_out 切图一致的细黑边（@3x 约 3px）。
  static const bubbleBorderWidth = 1.0;
}
