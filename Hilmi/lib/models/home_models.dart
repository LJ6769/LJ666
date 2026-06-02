import 'package:hilmi/utils/user_handle.dart';

/// 首页数据模型，后续由数据库/API 填充。
class ProfileStory {
  const ProfileStory({
    required this.id,
    this.imageUrl,
    this.name,
    this.email,
  });

  final String id;
  final String? imageUrl;
  final String? name;
  final String? email;
}

class LiveRoom {
  const LiveRoom({
    required this.id,
    this.coverUrl,
    this.hostName,
    this.hostId,
    this.hostHandle,
    this.hostEmail,
    this.hostAvatarUrl,
    this.videoUrl,
    this.title,
    this.isLive = true,
  });

  final String id;
  final String? coverUrl;
  final String? videoUrl;
  final String? hostName;
  final String? hostId;
  final String? hostHandle;
  final String? hostEmail;
  final String? hostAvatarUrl;
  final String? title;
  final bool isLive;

  /// 优先邮箱，否则 id；占位数据可回退 [hostHandle]。
  String get displayHostHandle {
    if (hostEmail != null || (hostId != null && hostId!.isNotEmpty)) {
      return formatUserHandle(email: hostEmail, userId: hostId);
    }
    return hostHandle ?? '@user';
  }
}

class TipsyBarRoom {
  const TipsyBarRoom({
    required this.id,
    this.coverUrl,
    this.title,
    this.description,
    this.participantAvatarUrls = const [],
    this.imageOnRight = false,
  });

  final String id;
  final String? coverUrl;
  final String? title;
  final String? description;
  final List<String?> participantAvatarUrls;
  final bool imageOnRight;
}

class HomeFeedData {
  const HomeFeedData({
    this.coinBalance = 0,
    this.profileStories = const [],
    this.liveRooms = const [],
    this.tipsyBarRooms = const [],
  });

  final int coinBalance;
  final List<ProfileStory> profileStories;
  final List<LiveRoom> liveRooms;
  final List<TipsyBarRoom> tipsyBarRooms;
}
