/// 副标题：优先完整邮箱；无邮箱则展示用户 id 前 12 位（无 `...`）。
String formatUserHandle({String? email, String? userId}) {
  final normalizedEmail = email?.trim();
  if (normalizedEmail != null &&
      normalizedEmail.isNotEmpty &&
      normalizedEmail.contains('@') &&
      normalizedEmail != 'null') {
    return normalizedEmail;
  }

  final id = userId?.trim();
  if (id == null || id.isEmpty) return '@user';

  final compact = id.replaceAll('-', '');
  if (compact.length > 12) return compact.substring(0, 12);
  return compact;
}
