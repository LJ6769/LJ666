// 应用启动时初始化 Supabase 客户端并暴露就绪状态。
import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppBootstrap {
  static bool _initialized = false;

  static bool get isReady => _initialized && SupabaseConfig.isConfigured;

  static Future<void> init() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        '[Supabase] Not configured. Set url and anonKey in lib/config/supabase_config.dart.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _initialized = true;
      debugPrint('[Supabase] Initialized → ${SupabaseConfig.url}');
    } catch (error, stack) {
      _initialized = false;
      debugPrint('[Supabase] Initialization failed: $error');
      debugPrint('$stack');
    }
  }

  static SupabaseClient? get client {
    if (!isReady) return null;
    try {
      return Supabase.instance.client;
    } catch (error) {
      debugPrint('[Supabase] Could not get client: $error');
      return null;
    }
  }
}
