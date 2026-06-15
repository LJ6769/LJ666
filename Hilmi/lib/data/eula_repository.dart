// EULA 同意时间戳写入（注册/登录字段）。
import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/config/config.dart';

/// EULA 同意状态（服务端：注册 eula_accepted_at / 登录 eula_login_accepted_at）。
class EulaRepository {
  const EulaRepository();

  Future<bool> hasAcceptedSignupByEmail(String email) async {
    return _hasColumnByEmail(email, 'eula_accepted_at');
  }

  Future<bool> hasAcceptedLoginByEmail(String email) async {
    return _hasColumnByEmail(email, 'eula_login_accepted_at');
  }

  Future<bool> hasAcceptedSignupForAuthUser(String authUserId) async {
    return _hasColumnByAuthUser(authUserId, 'eula_accepted_at');
  }

  Future<bool> hasAcceptedLoginForAuthUser(String authUserId) async {
    return _hasColumnByAuthUser(authUserId, 'eula_login_accepted_at');
  }

  Future<bool> _hasColumnByAuthUser(String authUserId, String column) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return false;

    final id = authUserId.trim();
    if (id.isEmpty) return false;

    try {
      final row = await client
          .from(SupabaseTables.user)
          .select(column)
          .eq('auth_user_id', id)
          .maybeSingle();
      return _hasTimestamp(row?[column]);
    } catch (error, stack) {
      debugPrint('[EulaRepository] $column by auth user: $error');
      debugPrint('$stack');
      return false;
    }
  }

  Future<bool> _hasColumnByEmail(String email, String column) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return false;

    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    try {
      final row = await client
          .from(SupabaseTables.user)
          .select(column)
          .eq('email', normalized)
          .maybeSingle();
      return _hasTimestamp(row?[column]);
    } catch (error, stack) {
      debugPrint('[EulaRepository] $column by email: $error');
      debugPrint('$stack');
      return false;
    }
  }

  /// 注册流程同意（写入 eula_accepted_at）。
  Future<void> acceptEulaSignup() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not configured.');
    }

    try {
      await client.rpc('accept_eula');
    } catch (error, stack) {
      debugPrint('[EulaRepository] acceptEulaSignup: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  /// 登录流程同意（写入 eula_login_accepted_at）。
  Future<void> acceptEulaLogin() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not configured.');
    }

    try {
      await client.rpc('accept_eula_login');
    } catch (error, stack) {
      debugPrint('[EulaRepository] acceptEulaLogin: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  static bool _hasTimestamp(dynamic raw) {
    if (raw == null) return false;
    if (raw is String) return raw.trim().isNotEmpty;
    return true;
  }
}
