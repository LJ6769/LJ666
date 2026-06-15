// 朋友圈首次左右滑动引导是否已完成的本地持久化。
import 'package:shared_preferences/shared_preferences.dart';

/// 朋友圈首次滑动引导完成状态。
abstract final class CircleGuideService {
  static const _completedKey = 'circle_feed_guide_completed_v1';

  static Future<bool> hasCompletedCircleGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> markCircleGuideCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
