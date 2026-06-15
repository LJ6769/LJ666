// Tipsy Bar 房间、成员、消息与进房详情模型。
import 'package:hilmi/utils/user_handle.dart';

/// 聊天室成员（麦位）。
class TipsyBarChatMember {
  const TipsyBarChatMember({
    required this.userId,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.avatarPath,
    this.isSpeaking = false,
    this.isHost = false,
    this.isVacantSeat = false,
  });

  final String userId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String? avatarPath;
  final bool isSpeaking;
  final bool isHost;

  /// UI 占位：嘉宾麦位暂无真人（与 [seat_empty] 一致）。
  final bool isVacantSeat;

  String get handle => formatUserHandle(email: email, userId: userId);

  static TipsyBarChatMember vacant() => const TipsyBarChatMember(
        userId: '',
        displayName: '',
        isVacantSeat: true,
      );
}

/// 聊天室消息。
class TipsyBarChatMessage {
  const TipsyBarChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    this.senderId,
    this.avatarUrl,
    this.isSystem = false,
    this.isOwn = false,
    this.createdAt,
  });

  final String id;
  final String? senderId;
  final String senderName;
  final String text;
  final String? avatarUrl;
  final bool isSystem;
  final bool isOwn;
  final DateTime? createdAt;

  static TipsyBarChatMessage tips(String text) => TipsyBarChatMessage(
        id: 'tips',
        senderName: 'Tips',
        text: text,
        isSystem: true,
      );

  factory TipsyBarChatMessage.fromRow(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? resolvedAvatarUrl,
  }) {
    final senderId = json['sender_id'] as String?;
    final profile = readEmbeddedProfile(json['User']);
    final displayName = profile?['display_name'] as String? ?? 'Guest';
    final isOwn =
        currentUserId != null && senderId != null && senderId == currentUserId;

    return TipsyBarChatMessage(
      id: json['id'] as String? ?? '',
      senderId: senderId,
      senderName: displayName,
      text: json['content'] as String? ?? '',
      avatarUrl: resolvedAvatarUrl,
      isOwn: isOwn,
      createdAt: _parseTime(json['created_at']),
    );
  }

  static Map<String, dynamic>? readEmbeddedProfile(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  static DateTime? _parseTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// 进入聊天室所需的房间与成员信息。
class TipsyBarChatRoomDetail {
  const TipsyBarChatRoomDetail({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    this.hostAudioUrl,
    this.hostAudioPath,
    required this.members,
  });

  final String id;
  final String title;
  final String? description;
  final String? coverUrl;

  /// 房主语音（Storage 签名 URL）。
  final String? hostAudioUrl;
  final String? hostAudioPath;
  final List<TipsyBarChatMember> members;

  TipsyBarChatMember? get host =>
      members.isNotEmpty ? members.firstWhere((m) => m.isHost, orElse: () => members.first) : null;

  /// 右侧麦位列数（空位可 Join in 上麦）。
  static const seatCount = 5;

  /// 种子嘉宾麦位数（第 2、3 位；不含房主）。
  static const seededGuestCount = 2;

  /// Join in 上麦起始索引（房主 + 嘉宾位之后）。
  static const joinSeatIndexStart = 1 + seededGuestCount;

  /// 列表卡片头像槽位数：房主 + 嘉宾空麦占位。
  static const cardAvatarSlotCount = joinSeatIndexStart;
}
