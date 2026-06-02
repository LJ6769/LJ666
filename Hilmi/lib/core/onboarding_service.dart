import 'package:shared_preferences/shared_preferences.dart';

/// 首次安装引导页完成状态（本地持久化）。
abstract final class OnboardingService {
  static const _completedKey = 'onboarding_completed_v1';

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
