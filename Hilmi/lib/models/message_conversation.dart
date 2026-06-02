/// 私信会话列表项（对应 Message 表 header 行 + 对方资料）。
class MessageConversation {
  const MessageConversation({
    required this.conversationId,
    required this.peerId,
    required this.peerName,
    this.peerEmail,
    this.peerAvatarUrl,
    this.lastPreview,
    this.lastMessageAt,
  });

  final String conversationId;
  final String peerId;
  final String peerName;
  final String? peerEmail;
  final String? peerAvatarUrl;
  final String? lastPreview;
  final DateTime? lastMessageAt;

  String get displayPreview {
    final text = lastPreview?.trim();
    if (text == null || text.isEmpty) {
      return 'Start a conversation…';
    }
    return text;
  }
}

/// 消息页顶部推荐用户（横滑大卡）。
class MessageFeaturedUser {
  const MessageFeaturedUser({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
}
