// 读写 public.User 表：当前登录用户资料 CRUD。
import 'package:supabase_flutter/supabase_flutter.dart';

/// 读写 public."User" 表（登录用户资料）。
class AuthRepository {
  const AuthRepository();

  static const _table = 'User';

  static const _selectColumns =
      'id, auth_user_id, email, display_name, bio, avatar_path, coins, liked_post_ids, following_ids, blocked_ids, eula_accepted_at, eula_login_accepted_at, apple_user_id';

  Future<Map<String, dynamic>?> findByAuthUserId(
    SupabaseClient client,
    String authUserId,
  ) {
    return client
        .from(_table)
        .select(_selectColumns)
        .eq('auth_user_id', authUserId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> findByEmail(
    SupabaseClient client,
    String email,
  ) {
    return client
        .from(_table)
        .select(_selectColumns)
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> findByAppleUserId(
    SupabaseClient client,
    String appleUserId,
  ) {
    final id = appleUserId.trim();
    if (id.isEmpty) return Future.value(null);
    return client
        .from(_table)
        .select(_selectColumns)
        .eq('apple_user_id', id)
        .maybeSingle();
  }

  Future<void> linkAuthUserId({
    required SupabaseClient client,
    required String profileId,
    required String authUserId,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final fields = <String, dynamic>{'auth_user_id': authUserId};
    if (normalizedEmail.isNotEmpty) {
      fields['email'] = normalizedEmail;
    }
    await client.from(_table).update(fields).eq('id', profileId);
  }

  Future<void> upsertProfile({
    required SupabaseClient client,
    required String authUserId,
    String? email,
    required String displayName,
    String? bio,
    String? avatarPath,
    String? appleUserId,
    bool eulaAccepted = false,
  }) async {
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    final existing = await findByAuthUserId(client, authUserId);

    final row = <String, dynamic>{
      'auth_user_id': authUserId,
      'display_name': displayName.trim().isEmpty ? 'Player' : displayName.trim(),
      if (normalizedEmail.isNotEmpty) 'email': normalizedEmail,
      if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
      if (avatarPath != null && avatarPath.isNotEmpty) 'avatar_path': avatarPath,
      if (appleUserId != null && appleUserId.trim().isNotEmpty)
        'apple_user_id': appleUserId.trim(),
      if (eulaAccepted)
        'eula_accepted_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing != null) {
      await client.from(_table).update(row).eq('auth_user_id', authUserId);
    } else {
      await client.from(_table).insert(row);
    }
  }

  Future<void> updateFields({
    required SupabaseClient client,
    required String authUserId,
    required Map<String, dynamic> fields,
  }) async {
    if (fields.isEmpty) return;
    await client.from(_table).update(fields).eq('auth_user_id', authUserId);
  }

  /// 删除触发器误建的重复资料行（同一 Apple 账号再次登录时）。
  Future<void> deleteByProfileId(
    SupabaseClient client,
    String profileId,
  ) async {
    final id = profileId.trim();
    if (id.isEmpty) return;
    await client.from(_table).delete().eq('id', id);
  }
}
