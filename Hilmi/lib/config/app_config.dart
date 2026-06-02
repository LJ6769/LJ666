import 'package:flutter/material.dart';

/// 应用级配置（启动、主题、网络超时等）。
abstract final class AppConfig {
  /// iOS Bundle ID（须与 Xcode、Apple Developer、Supabase Apple 登录一致）。
  static const String iosBundleId = 'com.live.Hilmi';

  /// 与启动页、主界面背景一致。
  static const Color splashBackground = Color(0xFFFEFAEF);

  static const Duration splashDuration = Duration(milliseconds: 1500);

  /// 首页聚合请求超时后回退占位数据。
  static const Duration supabaseHomeRequestTimeout = Duration(seconds: 12);
}
