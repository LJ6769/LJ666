import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/config/config.dart';

class BlockToggleResult {
  const BlockToggleResult({
    required this.isBlocked,
    required this.blockedIds,
  });

  final bool isBlocked;
  final List<String> blockedIds;
}

/// 拉黑关系（public."User".blocked_ids + RPC toggle_block）。
class BlockRepository {
  const BlockRepository();

  Future<BlockToggleResult?> toggleBlock(String targetUserId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    try {
      final raw = await client.rpc(
        'toggle_block',
        params: {'p_target_id': targetUserId},
      );
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      return BlockToggleResult(
        isBlocked: map['blocked'] as bool? ?? false,
        blockedIds: _readUuidList(map['blocked_ids']),
      );
    } catch (error, stack) {
      debugPrint('[BlockRepository] toggleBlock: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<List<String>> fetchMyBlockedIds() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final user = client.auth.currentUser;
      if (user == null) return const [];

      final row = await client
          .from(SupabaseTables.user)
          .select('blocked_ids')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (row == null) return const [];
      return _readUuidList(row['blocked_ids']);
    } catch (error, stack) {
      debugPrint('[BlockRepository] fetchMyBlockedIds: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  static List<String> _readUuidList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.startsWith('{') && raw.endsWith('}')) {
      final inner = raw.substring(1, raw.length - 1).trim();
      if (inner.isEmpty) return const [];
      return inner
          .split(',')
          .map((e) => e.trim())
          .where((id) => id.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
