import 'package:flutter/foundation.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 消息列表「删除」= 仅隐藏会话卡片；不删库内聊天记录。
abstract final class HiddenConversationsService {
  static const _keyPrefix = 'hidden_message_peer_ids_';

  static final hiddenPeerIds = ValueNotifier<Set<String>>(<String>{});

  static Set<String>? _cache;
  static String? _cacheUserId;
  static final Set<String> _pendingHiddenPeerIds = {};

  static void _publishHidden(Set<String> hidden) {
    hiddenPeerIds.value = Set<String>.from(hidden);
  }

  static Future<Set<String>> loadHiddenPeerIds() async {
    final userId = AuthService.cachedProfile?.id.trim();
    if (userId == null || userId.isEmpty) {
      final pending = Set<String>.from(_pendingHiddenPeerIds);
      _publishHidden(pending);
      return pending;
    }

    if (_cacheUserId == userId && _cache != null) {
      final merged = Set<String>.from({..._cache!, ..._pendingHiddenPeerIds});
      _publishHidden(merged);
      return merged;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('$_keyPrefix$userId') ?? const [];
    _cacheUserId = userId;
    _cache = Set<String>.from(stored);
    final merged = Set<String>.from({..._cache!, ..._pendingHiddenPeerIds});
    _publishHidden(merged);
    return merged;
  }

  static Future<void> hidePeer(String peerId) async {
    final id = peerId.trim();
    if (id.isEmpty) return;

    _pendingHiddenPeerIds.add(id);

    final userId = AuthService.cachedProfile?.id.trim();
    if (userId == null || userId.isEmpty) {
      _publishHidden(Set<String>.from(_pendingHiddenPeerIds));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('$_keyPrefix$userId') ?? const [];
    final hidden = Set<String>.from(stored)..add(id);
    _pendingHiddenPeerIds.remove(id);
    await _persist(userId, hidden);
  }

  /// 再次与该用户聊天时恢复列表展示。
  static Future<void> unhidePeer(String peerId) async {
    final id = peerId.trim();
    if (id.isEmpty) return;

    _pendingHiddenPeerIds.remove(id);

    final userId = AuthService.cachedProfile?.id.trim();
    if (userId == null || userId.isEmpty) {
      _publishHidden(Set<String>.from(_pendingHiddenPeerIds));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('$_keyPrefix$userId') ?? const [];
    final hidden = Set<String>.from(stored)..remove(id);
    await _persist(userId, hidden);
  }

  static Future<void> _persist(String userId, Set<String> hidden) async {
    _cacheUserId = userId;
    _cache = Set<String>.from(hidden);
    _publishHidden(hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_keyPrefix$userId', hidden.toList());
  }

  static void reset() {
    _cache = null;
    _cacheUserId = null;
    _pendingHiddenPeerIds.clear();
    _publishHidden({});
  }
}
