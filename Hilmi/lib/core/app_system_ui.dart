// 全局状态栏 / 导航栏样式：浅色页面用深色图标，深色页面用浅色图标。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/config/config.dart';

abstract final class AppSystemUi {
  /// 浅色背景页（首页、设置等）：状态栏图标/文字为深色。
  static const SystemUiOverlayStyle lightBackground = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppConfig.splashBackground,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// 深色背景页（直播间、视频通话等）：状态栏图标/文字为浅色。
  static const SystemUiOverlayStyle darkBackground = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static void applyLightBackground() {
    SystemChrome.setSystemUIOverlayStyle(lightBackground);
  }

  static void applyDarkBackground() {
    SystemChrome.setSystemUIOverlayStyle(darkBackground);
  }
}
