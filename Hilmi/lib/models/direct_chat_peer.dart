/// 私信聊天页对方（或从会话列表进入）。
class DirectChatPeer {
  const DirectChatPeer({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.conversationId,
  });

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? conversationId;
}
