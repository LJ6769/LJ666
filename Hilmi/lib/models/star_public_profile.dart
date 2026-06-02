import 'package:hilmi/utils/user_handle.dart';

/// 明星 / 用户公开资料（个人中心页）。
class StarPublicProfile {
  const StarPublicProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.bio,
    this.avatarUrl,
    this.avatarPath,
    this.featuredImageUrl,
    this.featuredImageCacheKey,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final String? avatarPath;
  final String? featuredImageUrl;
  final String? featuredImageCacheKey;

  String get handle => formatUserHandle(email: email, userId: id);

  String get introText {
    final text = bio?.trim();
    if (text != null && text.isNotEmpty) return text;
    return 'No intro yet.';
  }
}
