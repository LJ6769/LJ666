// 直播间弹幕历史、发送与 Realtime 订阅。
import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/live_chat_message.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:hilmi/utils/is_uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 直播间弹幕：历史加载、发送、Realtime 订阅。
class LiveChatRepository {
  const LiveChatRepository();

  static const _messageSelect = '''
id,
content,
created_at,
sender_id,
User!sender_id (
  display_name,
  avatar_path
)
''';

  static String? get _currentProfileId {
    final id = AuthService.cachedProfile?.id.trim();
    if (id != null && id.isNotEmpty) return id;
    final viewerId = ViewerSession.current?.id.trim();
    if (viewerId != null && viewerId.isNotEmpty) return viewerId;
    return null;
  }

  static const _messageSelectPlain = '''
id,
content,
created_at,
sender_id
''';

  Future<List<LiveChatMessage>> fetchMessages(
    String liveId, {
    int limit = 80,
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return [];
    if (!isUuid(liveId)) return [];

    try {
      final rows = await _queryMessages(
        client,
        liveId: liveId,
        select: _messageSelect,
        limit: limit,
      );
      return _mapMessageRows(rows, client);
    } catch (error, stack) {
      debugPrint('[LiveChatRepository] fetchMessages (with User): $error');
      debugPrint('$stack');
    }

    try {
      final rows = await _queryMessages(
        client,
        liveId: liveId,
        select: _messageSelectPlain,
        limit: limit,
      );
      return _mapMessageRows(rows, client);
    } catch (error, stack) {
      debugPrint('[LiveChatRepository] fetchMessages: $error');
      debugPrint('$stack');
      return [];
    }
  }

  Future<LiveChatMessage?> fetchMessageById(String messageId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    try {
      final row = await client
          .from(SupabaseTables.liveChat)
          .select(_messageSelect)
          .eq('id', messageId)
          .maybeSingle();
      if (row == null) return null;
      final message = LiveChatMessage.fromRow(
        row,
        currentProfileId: _currentProfileId,
        resolvedAvatarUrl: await _resolveMessageAvatarUrl(client, row),
      );
      return _applyLocalSenderProfile(
        await _enrichFromSenderId(message, client),
      );
    } catch (error, stack) {
      debugPrint('[LiveChatRepository] fetchMessageById: $error');
      debugPrint('$stack');
      return null;
    }
  }

  /// 删除当前用户发送的弹幕（需已登录）。
  Future<bool> deleteMessage(String messageId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return false;

    final id = messageId.trim();
    if (id.isEmpty) return false;

    if (!AuthService.isLoggedIn) {
      throw StateError('Not signed in');
    }

    try {
      await client.rpc(
        'delete_own_live_chat',
        params: {'p_message_id': id},
      );
      return true;
    } catch (error, stack) {
      debugPrint('[LiveChatRepository] deleteMessage: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  /// 发送弹幕（需已登录）。
  Future<LiveChatMessage> sendMessage({
    required String liveId,
    required String content,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw StateError('Not signed in');
    }
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not ready');
    }
    if (!isUuid(liveId)) {
      throw ArgumentError('Invalid live id');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    final senderId = await _resolveSenderId();
    final payload = <String, dynamic>{
      'live_id': liveId,
      'content': trimmed,
    };
    if (senderId != null) {
      payload['sender_id'] = senderId;
    }

    final row = await client
        .from(SupabaseTables.liveChat)
        .insert(payload)
        .select(_messageSelect)
        .single();

    final message = LiveChatMessage.fromRow(
      row,
      currentProfileId: _currentProfileId ?? senderId,
      resolvedAvatarUrl: await _resolveMessageAvatarUrl(client, row),
    );
    return _applyLocalSenderProfile(
      await _enrichFromSenderId(message, client),
    );
  }

  /// 登录用户用资料 id；未登录用 [ViewerSession] 随机观众 id（与送礼一致）。
  static Future<String?> _resolveSenderId() async {
    var profile = AuthService.cachedProfile;
    if (AuthService.isLoggedIn && profile == null) {
      profile = await AuthService.loadCurrentProfile();
    }
    final authId = profile?.id.trim();
    if (authId != null && authId.isNotEmpty) return authId;

    final viewer = await ViewerSession.ensureLoaded();
    final viewerId = viewer?.id.trim();
    if (viewerId != null && viewerId.isNotEmpty) return viewerId;
    return null;
  }

  static LiveChatMessage _applyLocalSenderProfile(LiveChatMessage message) {
    final senderId = message.senderId;
    if (senderId == null) return message;

    final profile = AuthService.cachedProfile;
    if (profile != null && profile.id == senderId) {
      final name = message.userName?.trim();
      return LiveChatMessage(
        id: message.id,
        senderId: message.senderId,
        text: message.text,
        userName: (name != null && name.isNotEmpty) ? name : profile.displayName,
        avatarUrl: message.avatarUrl ?? profile.avatarUrl,
        isSystem: message.isSystem,
        isOwn: message.isOwn,
        createdAt: message.createdAt,
      );
    }

    final viewer = ViewerSession.current;
    if (viewer != null && viewer.id == senderId) {
      final name = message.userName?.trim();
      return LiveChatMessage(
        id: message.id,
        senderId: message.senderId,
        text: message.text,
        userName:
            (name != null && name.isNotEmpty) ? name : viewer.displayName,
        avatarUrl: message.avatarUrl ?? viewer.avatarUrl,
        isSystem: message.isSystem,
        isOwn: message.isOwn,
        createdAt: message.createdAt,
      );
    }

    return message;
  }

  static Future<LiveChatMessage> _enrichFromSenderId(
    LiveChatMessage message,
    SupabaseClient client,
  ) async {
    final name = message.userName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        message.avatarUrl != null &&
        message.avatarUrl!.isNotEmpty) {
      return message;
    }

    final senderId = message.senderId;
    if (senderId == null || senderId.isEmpty) return message;

    try {
      final row = await client
          .from(SupabaseTables.user)
          .select('display_name, avatar_path')
          .eq('id', senderId)
          .maybeSingle();
      if (row == null) return message;

      final displayName = (row['display_name'] as String?)?.trim();
      final avatarPath = row['avatar_path'] as String?;
      String? avatarUrl = message.avatarUrl;
      if ((avatarUrl == null || avatarUrl.isEmpty) &&
          avatarPath != null &&
          avatarPath.isNotEmpty) {
        final resolved =
            await StorageMediaUrlResolver.resolve(avatarPath, client: client);
        if (resolved.isNotEmpty) avatarUrl = resolved;
      }

      return LiveChatMessage(
        id: message.id,
        senderId: message.senderId,
        text: message.text,
        userName: (name != null && name.isNotEmpty)
            ? name
            : (displayName != null && displayName.isNotEmpty
                ? displayName
                : message.userName),
        avatarUrl: avatarUrl,
        isSystem: message.isSystem,
        isOwn: message.isOwn,
        createdAt: message.createdAt,
      );
    } catch (error, stack) {
      debugPrint('[LiveChatRepository] enrich sender: $error');
      debugPrint('$stack');
      return message;
    }
  }

  Future<String?> _resolveMessageAvatarUrl(
    SupabaseClient client,
    Map<String, dynamic> row,
  ) async {
    final profile = LiveChatMessage.readEmbeddedProfile(
      row['User'] ?? row['profiles'],
    );
    final avatarPath = profile?['avatar_path'] as String?;
    if (avatarPath == null || avatarPath.isEmpty) return null;
    final url = await StorageMediaUrlResolver.resolve(
      avatarPath,
      client: client,
    );
    return url.isEmpty ? null : url;
  }

  RealtimeChannel subscribeInserts({
    required String liveId,
    required void Function(Map<String, dynamic> newRecord) onInsert,
  }) {
    final client = AppBootstrap.client!;
    final channel = client.channel('live_room:$liveId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: SupabaseTables.liveChat,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'live_id',
        value: liveId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (record.isEmpty) return;
        onInsert(record);
      },
    );

    channel.subscribe();
    return channel;
  }

  static Future<List<dynamic>> _queryMessages(
    SupabaseClient client, {
    required String liveId,
    required String select,
    required int limit,
  }) =>
      client
          .from(SupabaseTables.liveChat)
          .select(select)
          .eq('live_id', liveId)
          .order('created_at', ascending: true)
          .limit(limit) as Future<List<dynamic>>;

  static Future<List<LiveChatMessage>> _mapMessageRows(
    List<dynamic> rows,
    SupabaseClient client,
  ) async {
    final signed = await StorageMediaUrlResolver.resolveMany(
      rows.map((row) {
        final map = row as Map<String, dynamic>;
        return LiveChatMessage.readEmbeddedProfile(
          map['User'] ?? map['profiles'],
        )?['avatar_path'] as String?;
      }),
      client: client,
    );

    final messages = <LiveChatMessage>[];
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final avatarPath = LiveChatMessage.readEmbeddedProfile(
        map['User'] ?? map['profiles'],
      )?['avatar_path'] as String?;
      var message = LiveChatMessage.fromRow(
        map,
        currentProfileId: _currentProfileId,
        resolvedAvatarUrl: StorageMediaUrlResolver.pickNullable(
          signed,
          avatarPath,
        ),
      );
      message = _applyLocalSenderProfile(
        await _enrichFromSenderId(message, client),
      );
      messages.add(message);
    }
    return messages;
  }
}
