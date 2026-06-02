import 'package:hilmi/utils/user_handle.dart';

/// 朋友圈（Circle）帖子媒体项。
class CircleMedia {
  const CircleMedia({
    required this.type,
    required this.url,
    this.posterUrl,
    this.displayPath,
    this.videoPath,
  });

  final String type;
  /// 图片 URL，或视频 mp4（仅详情播放用；列表请用 [previewUrl]）。
  final String url;
  final String? posterUrl;

  /// 列表展示所用 Storage 路径（作磁盘缓存键）。
  final String? displayPath;

  /// 视频原文件路径（进详情/播放时再签名）。
  final String? videoPath;

  bool get isVideo => type == 'video';

  String get previewUrl {
    if (isVideo && posterUrl != null && posterUrl!.isNotEmpty) {
      return posterUrl!;
    }
    return url;
  }

  String? get previewCacheKey => displayPath;
}

/// 朋友圈帖子。
class CirclePost {
  const CirclePost({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorEmail,
    this.authorAvatarUrl,
    this.authorAvatarPath,
    this.media = const [],
    this.createdAt,
  });

  final String id;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorEmail;
  final String? authorAvatarUrl;
  final String? authorAvatarPath;
  final List<CircleMedia> media;
  final DateTime? createdAt;

  CircleMedia? get primaryMedia => media.isNotEmpty ? media.first : null;

  String get authorHandle =>
      formatUserHandle(email: authorEmail, userId: authorId);
}
