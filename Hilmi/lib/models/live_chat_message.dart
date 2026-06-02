/// 直播间弹幕 / 系统消息。
class LiveChatMessage {
  const LiveChatMessage({
    required this.text,
    this.id,
    this.senderId,
    this.userName,
    this.avatarUrl,
    this.isSystem = false,
    this.isOwn = false,
    this.createdAt,
  });

  final String? id;
  final String? senderId;
  final String text;
  final String? userName;
  final String? avatarUrl;
  final bool isSystem;
  final bool isOwn;
  final DateTime? createdAt;

  String get displayName {
    if (isSystem) return '';
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Guest';
  }

  static LiveChatMessage communityNotice(String text) => LiveChatMessage(
        isSystem: true,
        text: text,
      );

  factory LiveChatMessage.fromRow(
    Map<String, dynamic> json, {
    String? currentProfileId,
    String? resolvedAvatarUrl,
  }) {
    final senderId = json['sender_id'] as String?;
    final profile = readEmbeddedProfile(
      json['User'] ?? json['profiles'] ?? json['user'],
    );
    final displayName = profile?['display_name'] as String? ??
        json['sender_display_name'] as String?;
    final isOwn = currentProfileId != null &&
        senderId != null &&
        senderId == currentProfileId;

    return LiveChatMessage(
      id: json['id'] as String?,
      senderId: senderId,
      text: json['content'] as String? ?? '',
      userName: displayName,
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
