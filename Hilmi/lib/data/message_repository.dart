// 私信会话列表、Message 表 header 与推荐用户。
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/models/direct_chat_message.dart';
import 'package:hilmi/models/message_conversation.dart';
import 'package:uuid/uuid.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 私信列表：Message header + 推荐用户。
class MessageRepository {
  const MessageRepository();

  static const _headerSelect = '''
          conversation_id,
          user_low_id,
          user_high_id,
          last_message_at,
          last_message_preview
        ''';

  static const _chatSelect = '''
          id,
          body,
          sender_id,
          created_at,
          User!sender_id ( display_name, avatar_path )
        ''';

  static const _uuid = Uuid();

  Future<List<MessageFeaturedUser>> fetchFeaturedUsers({
    Set<String> blockedIds = const {},
    bool forceNetwork = false,
  }) async {
    if (!forceNetwork) {
      final cached = FeedDataCache.messageFeaturedPool;
      if (cached != null && cached.isNotEmpty) {
        return pickFeaturedDisplay(
          cached.toList(growable: false),
          excludeIds: _featuredExcludeIds(
            blockedIds: {...blockedIds, ...BlockService.blockedIds.value},
          ),
        );
      }
    }

    final pool = await _fetchFeaturedUserPool();
    if (pool.isNotEmpty) {
      FeedDataCache.setMessageFeaturedPool(pool);
    }
    return pickFeaturedDisplay(
      pool,
      excludeIds: _featuredExcludeIds(
        blockedIds: {...blockedIds, ...BlockService.blockedIds.value},
      ),
    );
  }

  /// 下拉刷新明星卡：仅从本地池重新随机，不请求数据库。
  static List<MessageFeaturedUser> reshuffleFeaturedFromLocalPool({
    Set<String> blockedIds = const {},
  }) {
    final cached = FeedDataCache.messageFeaturedPool;
    if (cached == null || cached.isEmpty) return const [];
    return pickFeaturedDisplay(
      cached.toList(growable: false),
      excludeIds: _featuredExcludeIds(
        blockedIds: {...blockedIds, ...BlockService.blockedIds.value},
      ),
    );
  }

  static Set<String> _featuredExcludeIds({Set<String> blockedIds = const {}}) {
    final exclude = <String>{...blockedIds};
    final myId = _currentUserId;
    if (myId != null && myId.isNotEmpty) {
      exclude.add(myId);
    }
    return exclude;
  }

  static List<MessageFeaturedUser> pickFeaturedDisplay(
    List<MessageFeaturedUser> pool, {
    Set<String> excludeIds = const {},
  }) {
    if (pool.isEmpty) return pool;
    final eligible = excludeIds.isEmpty
        ? pool
        : pool
            .where((user) => !excludeIds.contains(user.id))
            .toList(growable: false);
    if (eligible.isEmpty) return eligible;
    final shuffled = List<MessageFeaturedUser>.from(eligible)..shuffle(Random());
    if (shuffled.length <= FeedConfig.messageFeaturedDisplayCount) {
      return shuffled;
    }
    return shuffled
        .take(FeedConfig.messageFeaturedDisplayCount)
        .toList(growable: false);
  }

  /// 拉黑后保留未拉黑卡片，不足时从本地池补位（不整批重抽）。
  static List<MessageFeaturedUser> refillFeaturedAfterBlock({
    required List<MessageFeaturedUser> current,
    required List<MessageFeaturedUser> pool,
    required Set<String> blockedIds,
    String? myId,
  }) {
    final exclude = <String>{...blockedIds};
    if (myId != null && myId.isNotEmpty) {
      exclude.add(myId);
    }

    final kept = current
        .where((user) => !exclude.contains(user.id))
        .toList(growable: false);

    final removedSomeone = kept.length < current.length;
    if (removedSomeone &&
        current.length < FeedConfig.messageFeaturedDisplayCount) {
      return kept;
    }

    final keptIds = kept.map((user) => user.id).toSet();
    final result = List<MessageFeaturedUser>.from(kept);

    if (result.length < FeedConfig.messageFeaturedDisplayCount) {
      final candidates = pool
          .where(
            (user) =>
                !exclude.contains(user.id) && !keptIds.contains(user.id),
          )
          .toList(growable: false);
      final shuffled = List<MessageFeaturedUser>.from(candidates)
        ..shuffle(Random());
      for (final user in shuffled) {
        if (result.length >= FeedConfig.messageFeaturedDisplayCount) break;
        result.add(user);
        keptIds.add(user.id);
      }
    }

    return result
        .take(FeedConfig.messageFeaturedDisplayCount)
        .toList(growable: false);
  }

  static String? get _currentUserId {
    final id = AuthService.cachedProfile?.id.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<List<MessageFeaturedUser>> _fetchFeaturedUserPool() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    try {
      final myId = _currentUserId;

      var query = client.from(SupabaseTables.user).select(
        'id, display_name, email, avatar_path',
      );

      if (myId != null) {
        query = query.neq('id', myId);
      }

      // 不限 is_popular_star：种子男性、非明星用户、已注册账号均可进入随机池。
      final rows = await query
          .order('created_at', ascending: false)
          .limit(FeedConfig.messageFeaturedPoolLimit) as List<dynamic>;

      if (rows.isEmpty) return const [];

      final paths = <String?>[
        for (final row in rows)
          (row as Map<String, dynamic>)['avatar_path'] as String?,
      ];
      final signed =
          await StorageMediaUrlResolver.resolveMany(paths, client: client);

      return rows.map((row) {
        final map = row as Map<String, dynamic>;
        final avatarPath = map['avatar_path'] as String?;
        return MessageFeaturedUser(
          id: map['id'] as String,
          name: map['display_name'] as String? ?? 'Player',
          email: map['email'] as String?,
          avatarUrl: StorageMediaUrlResolver.pickNullable(signed, avatarPath),
        );
      }).toList();
    } catch (error, stack) {
      debugPrint('[MessageRepository] fetchFeaturedUserPool: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  Future<List<MessageConversation>> fetchConversations() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    final myId = AuthService.cachedProfile?.id;
    if (myId == null || myId.isEmpty) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.message)
          .select(_headerSelect)
          .eq('message_kind', 'header')
          .or('user_low_id.eq.$myId,user_high_id.eq.$myId')
          .order('last_message_at', ascending: false) as List<dynamic>;

      if (rows.isEmpty) return const [];

      final peerIds = <String>{};
      final parsed = <_HeaderRow>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final low = map['user_low_id'] as String?;
        final high = map['user_high_id'] as String?;
        if (low == null || high == null) continue;
        final peerId = low == myId ? high : low;
        peerIds.add(peerId);
        parsed.add(
          _HeaderRow(
            conversationId: map['conversation_id'] as String,
            peerId: peerId,
            lastPreview: map['last_message_preview'] as String?,
            lastMessageAt: _parseTime(map['last_message_at']),
          ),
        );
      }

      final peers = await _fetchUsersByIds(client, peerIds.toList());
      return [
        for (final h in parsed)
          MessageConversation(
            conversationId: h.conversationId,
            peerId: h.peerId,
            peerName: peers[h.peerId]?.name ?? 'Player',
            peerEmail: peers[h.peerId]?.email,
            peerAvatarUrl: peers[h.peerId]?.avatarUrl,
            lastPreview: h.lastPreview,
            lastMessageAt: h.lastMessageAt,
          ),
      ];
    } catch (error, stack) {
      debugPrint('[MessageRepository] fetchConversations: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  Future<String?> findConversationId(String peerId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    final myId = _currentUserId;
    if (myId == null) return null;

    final ordered = _orderedUserPair(myId, peerId);
    try {
      final row = await client
          .from(SupabaseTables.message)
          .select('conversation_id')
          .eq('message_kind', 'header')
          .eq('user_low_id', ordered.$1)
          .eq('user_high_id', ordered.$2)
          .maybeSingle();
      return row?['conversation_id'] as String?;
    } catch (error, stack) {
      debugPrint('[MessageRepository] findConversationId: $error');
      debugPrint('$stack');
      return null;
    }
  }

  Future<List<DirectChatMessage>> fetchChatMessages(String conversationId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return const [];

    final id = conversationId.trim();
    if (id.isEmpty) return const [];

    try {
      final rows = await client
          .from(SupabaseTables.message)
          .select(_chatSelect)
          .eq('conversation_id', id)
          .eq('message_kind', 'chat')
          .order('created_at', ascending: true) as List<dynamic>;

      if (rows.isEmpty) return const [];

      final paths = <String?>[
        for (final row in rows)
          _readEmbeddedProfile((row as Map)['User'])?['avatar_path'] as String?,
      ];
      final signed =
          await StorageMediaUrlResolver.resolveMany(paths, client: client);

      return rows.map((row) {
        final map = row as Map<String, dynamic>;
        final profile = _readEmbeddedProfile(map['User']);
        final avatarPath = profile?['avatar_path'] as String?;
        return DirectChatMessage(
          id: map['id'] as String,
          body: (map['body'] as String? ?? '').trim(),
          senderId: map['sender_id'] as String? ?? '',
          createdAt: _parseTime(map['created_at']) ?? DateTime.now(),
          senderName: profile?['display_name'] as String?,
          senderAvatarUrl:
              StorageMediaUrlResolver.pickNullable(signed, avatarPath),
        );
      }).toList();
    } catch (error, stack) {
      debugPrint('[MessageRepository] fetchChatMessages: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  /// 删除整段私信会话（header + 全部 chat 消息）。
  Future<bool> deleteConversation(String conversationId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return false;

    final id = conversationId.trim();
    if (id.isEmpty) return false;

    if (_currentUserId == null) {
      throw StateError('Not signed in');
    }

    try {
      await client.rpc(
        'delete_direct_conversation',
        params: {'p_conversation_id': id},
      );
      return true;
    } catch (error, stack) {
      debugPrint('[MessageRepository] deleteConversation: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<DirectChatMessage> sendChatMessage({
    required String peerId,
    required String body,
    String? conversationId,
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not ready');
    }

    final myId = _currentUserId;
    if (myId == null) {
      throw StateError('Not signed in');
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    final ordered = _orderedUserPair(myId, peerId);
    var convId = conversationId?.trim();
    if (convId == null || convId.isEmpty) {
      convId = await findConversationId(peerId);
    }
    convId ??= _uuid.v4();

    final row = await client
        .from(SupabaseTables.message)
        .insert({
          'conversation_id': convId,
          'message_kind': 'chat',
          'user_low_id': ordered.$1,
          'user_high_id': ordered.$2,
          'sender_id': myId,
          'body': trimmed,
        })
        .select(_chatSelect)
        .single();

    final map = Map<String, dynamic>.from(row);
    final profile = _readEmbeddedProfile(map['User']);
    final avatarPath = profile?['avatar_path'] as String?;
    String? avatarUrl;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarUrl = await StorageMediaUrlResolver.resolve(avatarPath, client: client);
    }

    return DirectChatMessage(
      id: map['id'] as String,
      body: trimmed,
      senderId: myId,
      createdAt: _parseTime(map['created_at']) ?? DateTime.now(),
      senderName: profile?['display_name'] as String? ?? AuthService.cachedProfile?.displayName,
      senderAvatarUrl: avatarUrl ?? AuthService.cachedProfile?.avatarUrl,
    );
  }

  static (String, String) _orderedUserPair(String a, String b) {
    return a.compareTo(b) < 0 ? (a, b) : (b, a);
  }

  static Map<String, dynamic>? _readEmbeddedProfile(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  Future<Map<String, _PeerProfile>> _fetchUsersByIds(
    SupabaseClient client,
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};

    final rows = await client
        .from(SupabaseTables.user)
        .select('id, display_name, email, avatar_path')
        .inFilter('id', userIds) as List<dynamic>;

    final paths = <String?>[
      for (final row in rows)
        (row as Map<String, dynamic>)['avatar_path'] as String?,
    ];
    final signed =
        await StorageMediaUrlResolver.resolveMany(paths, client: client);

    final result = <String, _PeerProfile>{};
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String?;
      if (id == null) continue;
      final avatarPath = map['avatar_path'] as String?;
      result[id] = _PeerProfile(
        name: map['display_name'] as String? ?? 'Player',
        email: map['email'] as String?,
        avatarUrl: StorageMediaUrlResolver.pickNullable(signed, avatarPath),
      );
    }
    return result;
  }

  static DateTime? _parseTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

class _HeaderRow {
  const _HeaderRow({
    required this.conversationId,
    required this.peerId,
    this.lastPreview,
    this.lastMessageAt,
  });

  final String conversationId;
  final String peerId;
  final String? lastPreview;
  final DateTime? lastMessageAt;
}

class _PeerProfile {
  const _PeerProfile({
    required this.name,
    this.email,
    this.avatarUrl,
  });

  final String name;
  final String? email;
  final String? avatarUrl;
}
