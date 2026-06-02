/// 将用户邮箱映射为 Storage 中 `users/` 下的文件夹名。
abstract final class StorageUserFolder {
  /// 规范化邮箱作为路径段（小写；仅保留邮箱常见字符）。
  static String fromEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return 'unknown';
    return normalized.replaceAll(RegExp(r'[^a-z0-9@._+-]'), '_');
  }

  /// 用户头像在 media 桶中的路径：`users/{email}/avatar_{ts}.{ext}`。
  static String avatarObjectPath({
    required String email,
    required String extension,
    int? timestampMs,
  }) {
    final folder = fromEmail(email);
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final ext = extension.toLowerCase();
    return 'users/$folder/avatar_$ts.$ext';
  }
}
