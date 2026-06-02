import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/tipsy_bar_chat.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tipsy Bar 聊天室：房间详情、公屏聊天（历史 / 发送 / Realtime）。
class TipsyBarChatRepository {
  const TipsyBarChatRepository();

  static const _roomSelect = '''
          id,
          room_index,
          title,
          description,
          cover_path,
          host_audio_path,
          ChatRoomMember (
            sort_order,
            User (
              id,
              display_name,
              email,
              avatar_path
            )
          )
        ''';

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

  static const _messageSelectPlain = '''
id,
content,
created_at,
sender_id
''';

  static const _tipsText =
      'Please keep the conversation civil and respectful. '
      'Harassment, hate speech, or inappropriate content is not allowed.';

  static String? get _currentUserId {
    final id = AuthService.cachedProfile?.id.trim();
    if (id != null && id.isNotEmpty) return id;
    final viewerId = ViewerSession.current?.id.trim();
    if (viewerId != null && viewerId.isNotEmpty) return viewerId;
    return null;
  }

  TipsyBarChatMessage communityTips() => TipsyBarChatMessage.tips(_tipsText);

  /// 房主删除聊天室（需已登录且为 sort_order=0 的房主）。
  Future<bool> deleteRoom(String roomId) async {
    if (!AuthService.isLoggedIn) {
      throw StateError('Not signed in');
    }

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not ready');
    }

    final id = roomId.trim();
    if (id.isEmpty) return false;

    try {
      await client.rpc(
        'delete_tipsy_chat_room',
        params: {'p_room_id': id},
      );
      FeedDataCache.invalidateHomeFeed();
      return true;
    } catch (error, stack) {
      debugPrint('[TipsyBarChatRepository] deleteRoom: $error');
      debugPrint('$stack');
      rethrow;
    }
  }

  Future<TipsyBarChatRoomDetail?> fetchRoomDetail(String roomId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;
    final id = roomId.trim();
    if (id.isEmpty) return null;

    try {
      final row = await client
          .from(SupabaseTables.chatRoom)
          .select(_roomSelect)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _mapRoom(Map<String, dynamic>.from(row), client);
    } catch (error, stack) {
      debugPrint('[TipsyBarChatRepository] fetchRoomDetail: $error');
      debugPrint('$stack');
      return null;
    }
  }

  Future<List<TipsyBarChatMessage>> fetchMessages(
    String roomId, {
    int limit = 80,
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return [];

    try {
      final rows = await _queryMessages(
        client,
        roomId: roomId,
        select: _messageSelect,
        limit: limit,
      );
      return _mapMessageRows(rows, client);
    } catch (error, stack) {
      debugPrint('[TipsyBarChatRepository] fetchMessages (with User): $error');
      debugPrint('$stack');
    }

    final rows = await _queryMessages(
      client,
      roomId: roomId,
      select: _messageSelectPlain,
      limit: limit,
    );
    return _mapMessageRows(rows, client);
  }

  Future<TipsyBarChatMessage?> fetchMessageById(String messageId) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) return null;

    try {
      final row = await client
          .from(SupabaseTables.chatRoomChat)
          .select(_messageSelect)
          .eq('id', messageId)
          .maybeSingle();
      if (row == null) return null;
      final message = TipsyBarChatMessage.fromRow(
        Map<String, dynamic>.from(row),
        currentUserId: _currentUserId,
        resolvedAvatarUrl: await _resolveMessageAvatarUrl(
          client,
          Map<String, dynamic>.from(row),
        ),
      );
      return _applyLocalSenderProfile(
        await _enrichFromSenderId(message, client),
      );
    } catch (error, stack) {
      debugPrint('[TipsyBarChatRepository] fetchMessageById: $error');
      debugPrint('$stack');
      return null;
    }
  }

  Future<TipsyBarChatMessage> sendMessage({
    required String roomId,
    required String content,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw StateError('Not signed in');
    }
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not ready');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    final senderId = await _resolveSenderId();
    final payload = <String, dynamic>{
      'chat_room_id': roomId,
      'content': trimmed,
    };
    if (senderId != null) {
      payload['sender_id'] = senderId;
    }

    final row = await client
        .from(SupabaseTables.chatRoomChat)
        .insert(payload)
        .select(_messageSelect)
        .single();

    final message = TipsyBarChatMessage.fromRow(
      Map<String, dynamic>.from(row),
      currentUserId: _currentUserId ?? senderId,
      resolvedAvatarUrl: await _resolveMessageAvatarUrl(
        client,
        Map<String, dynamic>.from(row),
      ),
    );
    return _applyLocalSenderProfile(
      await _enrichFromSenderId(message, client),
    );
  }

  RealtimeChannel subscribeInserts({
    required String roomId,
    required void Function(Map<String, dynamic> newRecord) onInsert,
  }) {
    final client = AppBootstrap.client!;
    final channel = client.channel('tipsy_bar_room:$roomId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: SupabaseTables.chatRoomChat,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_room_id',
        value: roomId,
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

  Future<TipsyBarChatRoomDetail?> _mapRoom(
    Map<String, dynamic> map,
    SupabaseClient client,
  ) async {
    final roomIndex = map['room_index'] as int?;
    final hostAudioPath = _resolveHostAudioPath(
      map['host_audio_path'] as String?,
      roomIndex,
    );

    final mediaPaths = <String?>[
      map['cover_path'] as String?,
      hostAudioPath,
    ];

    final memberRows = _readEmbeddedMembers(map['ChatRoomMember'])
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
          b['sort_order'] as int? ?? 0,
        ),
      );

    final members = <TipsyBarChatMember>[];
    for (final member in memberRows) {
      final sortOrder = member['sort_order'] as int? ?? 0;
      final profile = _readEmbeddedProfile(member['User']);
      if (profile == null) continue;
      final userId = profile['id'] as String?;
      if (userId == null || userId.isEmpty) continue;
      mediaPaths.add(profile['avatar_path'] as String?);
      members.add(
        TipsyBarChatMember(
          userId: userId,
          displayName: profile['display_name'] as String? ?? 'User',
          email: profile['email'] as String?,
          avatarPath: profile['avatar_path'] as String?,
          isHost: sortOrder == 0,
        ),
      );
    }

    final signed = await StorageMediaUrlResolver.resolveMany(
      mediaPaths,
      client: client,
    );

    final resolvedMembers = [
      for (final m in members)
        TipsyBarChatMember(
          userId: m.userId,
          displayName: m.displayName,
          email: m.email,
          avatarUrl: StorageMediaUrlResolver.pickNullable(signed, m.avatarPath),
          avatarPath: m.avatarPath,
          isHost: m.isHost,
          isSpeaking: m.isHost,
        ),
    ];

    return TipsyBarChatRoomDetail(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Tipsy Bar',
      description: map['description'] as String?,
      coverUrl: StorageMediaUrlResolver.pickNullable(
        signed,
        map['cover_path'] as String?,
      ),
      hostAudioUrl: StorageMediaUrlResolver.pickNullable(signed, hostAudioPath),
      hostAudioPath: hostAudioPath,
      members: _membersForRoom(resolvedMembers),
    );
  }

  static String? _resolveHostAudioPath(String? fromDb, int? roomIndex) {
    final trimmed = fromDb?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (roomIndex == null || roomIndex < 1) return null;
    return 'chat-audio/$roomIndex.mp3';
  }

  List<TipsyBarChatMember> _membersForRoom(List<TipsyBarChatMember> all) {
    if (all.isEmpty) return const [];
    final hosts = all.where((m) => m.isHost).toList();
    final host = hosts.isNotEmpty ? hosts.first : all.first;
    final guests = all.where((m) => !m.isHost && !m.isVacantSeat).toList();
    final roster = <TipsyBarChatMember>[host];
    for (var i = 0; i < TipsyBarChatRoomDetail.seededGuestCount; i++) {
      roster.add(
        i < guests.length ? guests[i] : TipsyBarChatMember.vacant(),
      );
    }
    return roster;
  }

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

  static TipsyBarChatMessage _applyLocalSenderProfile(TipsyBarChatMessage message) {
    final senderId = message.senderId;
    if (senderId == null) return message;

    final profile = AuthService.cachedProfile;
    if (profile != null && profile.id == senderId) {
      return TipsyBarChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: profile.displayName,
        text: message.text,
        avatarUrl: message.avatarUrl ?? profile.avatarUrl,
        isOwn: true,
        createdAt: message.createdAt,
      );
    }

    final viewer = ViewerSession.current;
    if (viewer != null && viewer.id == senderId) {
      return TipsyBarChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: viewer.displayName,
        text: message.text,
        avatarUrl: message.avatarUrl ?? viewer.avatarUrl,
        isOwn: true,
        createdAt: message.createdAt,
      );
    }

    return message;
  }

  static Future<TipsyBarChatMessage> _enrichFromSenderId(
    TipsyBarChatMessage message,
    SupabaseClient client,
  ) async {
    final name = message.senderName.trim();
    if (name.isNotEmpty &&
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

      return TipsyBarChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: displayName != null && displayName.isNotEmpty
            ? displayName
            : message.senderName,
        text: message.text,
        avatarUrl: avatarUrl,
        isOwn: message.isOwn,
        createdAt: message.createdAt,
      );
    } catch (error, stack) {
      debugPrint('[TipsyBarChatRepository] enrich sender: $error');
      debugPrint('$stack');
      return message;
    }
  }

  Future<String?> _resolveMessageAvatarUrl(
    SupabaseClient client,
    Map<String, dynamic> row,
  ) async {
    final profile = TipsyBarChatMessage.readEmbeddedProfile(row['User']);
    final avatarPath = profile?['avatar_path'] as String?;
    if (avatarPath == null || avatarPath.isEmpty) return null;
    final url = await StorageMediaUrlResolver.resolve(
      avatarPath,
      client: client,
    );
    return url.isEmpty ? null : url;
  }

  static Future<List<dynamic>> _queryMessages(
    SupabaseClient client, {
    required String roomId,
    required String select,
    required int limit,
  }) =>
      client
          .from(SupabaseTables.chatRoomChat)
          .select(select)
          .eq('chat_room_id', roomId)
          .order('created_at', ascending: true)
          .limit(limit) as Future<List<dynamic>>;

  static Future<List<TipsyBarChatMessage>> _mapMessageRows(
    List<dynamic> rows,
    SupabaseClient client,
  ) async {
    final signed = await StorageMediaUrlResolver.resolveMany(
      rows.map((row) {
        final map = row as Map<String, dynamic>;
        return TipsyBarChatMessage.readEmbeddedProfile(map['User'])
            ?['avatar_path'] as String?;
      }),
      client: client,
    );

    final messages = <TipsyBarChatMessage>[];
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final avatarPath = TipsyBarChatMessage.readEmbeddedProfile(map['User'])
          ?['avatar_path'] as String?;
      var message = TipsyBarChatMessage.fromRow(
        map,
        currentUserId: _currentUserId,
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

  List<Map<String, dynamic>> _readEmbeddedMembers(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>) item,
      ];
    }
    if (raw is Map<String, dynamic>) return [raw];
    return const [];
  }

  Map<String, dynamic>? _readEmbeddedProfile(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }
}
