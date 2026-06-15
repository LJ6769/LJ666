// 关注/粉丝列表中的用户行模型。
import 'package:hilmi/utils/user_handle.dart';
import 'package:hilmi/models/direct_chat_peer.dart';

/// 关注列表中的用户摘要。
class FollowUser {
  const FollowUser({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarPath,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? avatarPath;
  final String? avatarUrl;

  String get handle => formatUserHandle(email: email, userId: id);

  bool get hasAvatar =>
      (avatarUrl != null && avatarUrl!.isNotEmpty) ||
      (avatarPath != null && avatarPath!.isNotEmpty);

  DirectChatPeer toDirectChatPeer() => DirectChatPeer(
        id: id,
        name: displayName,
        email: email,
        avatarUrl: avatarUrl,
      );
}
