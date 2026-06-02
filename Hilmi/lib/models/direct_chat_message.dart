/// 私信单条 chat 消息。
class DirectChatMessage {
  const DirectChatMessage({
    required this.id,
    required this.body,
    required this.senderId,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  final String id;
  final String body;
  final String senderId;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatarUrl;
}
