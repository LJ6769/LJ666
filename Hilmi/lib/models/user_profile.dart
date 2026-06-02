/// 当前登录用户在 public."User" 表中的资料。
class UserProfile {
  const UserProfile({
    required this.id,
    required this.authUserId,
    required this.displayName,
    this.email,
    this.bio,
    this.avatarPath,
    this.avatarUrl,
    this.coins = 0,
    this.likedPostIds = const [],
    this.followingIds = const [],
    this.blockedIds = const [],
    this.eulaAcceptedAt,
  });

  final String id;
  final String authUserId;
  final String displayName;
  final String? email;
  final String? bio;
  final String? avatarPath;
  final String? avatarUrl;
  final int coins;
  final List<String> likedPostIds;
  final List<String> followingIds;
  final List<String> blockedIds;
  final DateTime? eulaAcceptedAt;

  bool get hasAcceptedEula => eulaAcceptedAt != null;

  bool get hasAvatar =>
      (avatarUrl != null && avatarUrl!.isNotEmpty) ||
      (avatarPath != null && avatarPath!.isNotEmpty);

  UserProfile copyWith({
    int? coins,
    List<String>? likedPostIds,
    List<String>? followingIds,
    List<String>? blockedIds,
  }) {
    return UserProfile(
      id: id,
      authUserId: authUserId,
      displayName: displayName,
      email: email,
      bio: bio,
      avatarPath: avatarPath,
      avatarUrl: avatarUrl,
      coins: coins ?? this.coins,
      likedPostIds: likedPostIds ?? this.likedPostIds,
      followingIds: followingIds ?? this.followingIds,
      blockedIds: blockedIds ?? this.blockedIds,
      eulaAcceptedAt: eulaAcceptedAt,
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    String? avatarUrl,
  }) {
    return UserProfile(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Player',
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      avatarPath: json['avatar_path'] as String?,
      avatarUrl: avatarUrl,
      coins: _readInt(json['coins']),
      likedPostIds: _readUuidList(json['liked_post_ids']),
      followingIds: _readUuidList(json['following_ids']),
      blockedIds: _readUuidList(json['blocked_ids']),
      eulaAcceptedAt: _parseTime(json['eula_accepted_at']),
    );
  }

  static DateTime? _parseTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static List<String> _readUuidList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  static int _readInt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }
}
