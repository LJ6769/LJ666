import 'package:flutter/material.dart';

/// EULA / 协议弹层布局常量（切图 @3x，数值 = 像素 ÷ 3）。
abstract final class LegalLayout {
  static const designWidth = 375.0;
  static const sheetHeight = 680.0;
  static const sheetTopInsetFraction = 0.28;

  static const cream = Color(0xFFFEFAEF);
  static const sheetRadius = 28.0;
  static const borderWidth = 2.5;

  static const headerTop = 20.0;
  static const headerPadH = 20.0;
  static const titleSize = 18.0;
  static const closeSize = 35.0;

  static const bodyPadH = 20.0;
  static const bodySize = 14.0;
  static const headerToBody = 16.0;

  static const confirmH = 51.0;
  static const confirmBottom = 12.0;
  static const confirmTop = 8.0;
  static const confirmTextSize = 16.0;
}
