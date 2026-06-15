// 上传封面并 RPC 创建 Tipsy Bar 聊天室。
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:hilmi/utils/tipsy_bar_display_slots.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 创建 Tipsy Bar 聊天室结果。
class TipsyBarRoomCreateResult {
  const TipsyBarRoomCreateResult({
    required this.room,
    required this.remainingCoins,
  });

  final TipsyBarRoom room;
  final int remainingCoins;
}

/// 上传封面并调用 Supabase RPC 创建聊天室。
abstract final class TipsyBarRoomCreator {
  static const createCost = 20;

  static Future<TipsyBarRoomCreateResult> create({
    required String title,
    required String description,
    required XFile coverImage,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw StateError('Please sign in to create a room.');
    }

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not configured.');
    }

    var profile = AuthService.cachedProfile;
    if (profile == null) {
      profile = await AuthService.loadCurrentProfile();
    }
    if (profile == null) {
      throw StateError('Profile not found. Please sign in again.');
    }

    if (profile.coins < createCost) {
      throw StateError('Not enough coins.');
    }

    final coverPath = await _uploadCover(
      client: client,
      authorId: profile.id,
      coverImage: coverImage,
    );

    try {
      final raw = await client.rpc(
        'create_tipsy_chat_room',
        params: {
          'p_title': title.trim(),
          'p_description': description.trim(),
          'p_cover_path': coverPath,
        },
      );

      if (raw is! Map) {
        throw StateError('Create room failed. Please try again.');
      }

      final map = Map<String, dynamic>.from(raw);
      final roomId = map['room_id']?.toString().trim() ?? '';
      if (roomId.isEmpty) {
        throw StateError('Create room failed. Please try again.');
      }

      final remainingCoins = _readInt(map['coins']) ?? profile.coins - createCost;
      AuthService.patchCoins(remainingCoins);
      await AuthService.loadCurrentProfile(forceRefresh: true);

      final room = await _loadRoomPreview(client, roomId);
      if (room == null) {
        throw StateError('Room created but could not be loaded.');
      }

      return TipsyBarRoomCreateResult(
        room: room,
        remainingCoins: remainingCoins,
      );
    } on PostgrestException catch (error) {
      debugPrint('[TipsyBarRoomCreator] rpc: ${error.message}');
      final msg = error.message.toLowerCase();
      if (msg.contains('insufficient coins') || msg.contains('not enough')) {
        throw StateError('Not enough coins.');
      }
      if (msg.contains('not authenticated')) {
        throw StateError('Please sign in to create a room.');
      }
      rethrow;
    }
  }

  static Future<String> _uploadCover({
    required SupabaseClient client,
    required String authorId,
    required XFile coverImage,
  }) async {
    final file = File(coverImage.path);
    if (!await file.exists()) {
      throw StateError('Cover image not found.');
    }

    final ext = _imageExtension(coverImage.path);
    final storagePath =
        'chat-rooms/custom/$authorId/${_uniqueBaseName()}.$ext';

    await client.storage.from(SupabaseConfig.mediaBucket).upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _imageContentType(ext),
          ),
        );

    return storagePath;
  }

  static Future<TipsyBarRoom?> _loadRoomPreview(
    SupabaseClient client,
    String roomId,
  ) async {
    const select = '''
          id,
          title,
          description,
          cover_path,
          image_on_right,
          ChatRoomMember (
            sort_order,
            User (
              id,
              avatar_path
            )
          )
        ''';

    final row = await client
        .from(SupabaseTables.chatRoom)
        .select(select)
        .eq('id', roomId)
        .maybeSingle();

    if (row == null) return null;

    final map = Map<String, dynamic>.from(row);
    final coverPath = map['cover_path'] as String?;
    final mediaPaths = <String?>[coverPath];

    final members = _readEmbeddedMembers(map['ChatRoomMember'])
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
          b['sort_order'] as int? ?? 0,
        ),
      );
    for (final member in members.take(5)) {
      final profile = _readEmbeddedProfile(member['User']);
      mediaPaths.add(profile?['avatar_path'] as String?);
    }

    final signed = await StorageMediaUrlResolver.resolveMany(
      mediaPaths,
      client: client,
    );

    final participantUrls = tipsyBarCardParticipantAvatars([
      for (final member in members.take(5))
        StorageMediaUrlResolver.pickNullable(
          signed,
          _readEmbeddedProfile(member['User'])?['avatar_path'] as String?,
        ),
    ]);

    final hostProfile = members.isEmpty
        ? null
        : _readEmbeddedProfile(members.first['User']);
    final hostId = (hostProfile?['id'] as String?)?.trim() ?? '';

    return TipsyBarRoom(
      id: map['id'] as String,
      coverUrl: StorageMediaUrlResolver.pickNullable(signed, coverPath),
      title: map['title'] as String?,
      description: map['description'] as String?,
      hostUserId: hostId.isEmpty ? null : hostId,
      participantUserIds: [
        for (final member in members)
          (_readEmbeddedProfile(member['User'])?['id'] as String?)?.trim() ??
              '',
      ].where((id) => id.isNotEmpty).toList(growable: false),
      participantAvatarUrls: participantUrls,
      imageOnRight: map['image_on_right'] as bool? ?? false,
    );
  }

  static List<Map<String, dynamic>> _readEmbeddedMembers(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>) item,
      ];
    }
    if (raw is Map<String, dynamic>) return [raw];
    return const [];
  }

  static Map<String, dynamic>? _readEmbeddedProfile(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  static int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static String _uniqueBaseName() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch}_${r.nextInt(0x7fffffff)}';
  }

  static String _imageExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png') return 'png';
    if (ext == 'webp') return 'webp';
    if (ext == 'jpeg' || ext == 'jpg') return 'jpg';
    return 'jpg';
  }

  static String _imageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
