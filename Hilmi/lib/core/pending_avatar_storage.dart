import 'package:shared_preferences/shared_preferences.dart';

/// 注册时尚未登录，暂存头像本地路径，首次登录后上传。
abstract final class PendingAvatarStorage {
  static String _key(String email) =>
      'pending_avatar_${email.trim().toLowerCase()}';

  static Future<void> save(String email, String localPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(email), localPath);
  }

  static Future<String?> take(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(email);
    final path = prefs.getString(key);
    if (path != null) {
      await prefs.remove(key);
    }
    return path;
  }
}
