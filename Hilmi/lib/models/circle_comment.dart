// 朋友圈帖子评论模型（PostChat 表行）。
import 'package:hilmi/utils/user_handle.dart';

/// 朋友圈帖子评论（PostChat 表）。
class CircleComment {
  const CircleComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    this.authorEmail,
    this.authorAvatarUrl,
    this.authorAvatarPath,
    this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String content;
  final String? authorEmail;
  final String? authorAvatarUrl;
  final String? authorAvatarPath;
  final DateTime? createdAt;

  String get authorHandle =>
      formatUserHandle(email: authorEmail, userId: authorId);
}
