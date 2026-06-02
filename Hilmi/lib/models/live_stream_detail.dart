import 'package:hilmi/utils/user_handle.dart';

/// 直播间详情（进房后拉取，含已签名的 video URL）。
class LiveStreamDetail {
  const LiveStreamDetail({
    required this.id,
    this.description,
    this.coverUrl,
    this.videoUrl,
    this.streamerId,
    this.streamerName,
    this.streamerEmail,
    this.streamerAvatarUrl,
    this.viewerCount = 0,
    this.isLive = true,
    this.tags = const [],
    this.categorySlug,
    this.categoryName,
  });

  final String id;
  final String? description;
  final String? coverUrl;
  final String? videoUrl;
  final String? streamerId;
  final String? streamerName;
  final String? streamerEmail;
  final String? streamerAvatarUrl;
  final int viewerCount;
  final bool isLive;
  final List<String> tags;
  final String? categorySlug;
  final String? categoryName;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  String get streamerHandle =>
      formatUserHandle(email: streamerEmail, userId: streamerId);
}
