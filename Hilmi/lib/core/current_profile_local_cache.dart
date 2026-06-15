// 当前用户资料本地持久化（头像等），减少重复拉取 public."User"。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录用户资料本地缓存（按 auth_user_id 分桶）。
abstract final class CurrentProfileLocalCache {
  CurrentProfileLocalCache._();

  static const _keyPrefix = 'cached_user_profile_v1_';

  static Future<void> save(UserProfile profile) async {
    final authUserId = profile.authUserId.trim();
    if (authUserId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_keyPrefix$authUserId',
        jsonEncode(profile.toJson()),
      );
    } catch (error, stack) {
      debugPrint('[CurrentProfileLocalCache] save: $error');
      debugPrint('$stack');
    }
  }

  static Future<UserProfile?> load(String authUserId) async {
    final id = authUserId.trim();
    if (id.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$id');
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(
        map,
        avatarUrl: map['avatar_url'] as String?,
      );
    } catch (error, stack) {
      debugPrint('[CurrentProfileLocalCache] load: $error');
      debugPrint('$stack');
      return null;
    }
  }

  static Future<void> clear([String? authUserId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = authUserId?.trim() ?? '';
      if (id.isNotEmpty) {
        await prefs.remove('$_keyPrefix$id');
        return;
      }

      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(_keyPrefix))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (error, stack) {
      debugPrint('[CurrentProfileLocalCache] clear: $error');
      debugPrint('$stack');
    }
  }
}
