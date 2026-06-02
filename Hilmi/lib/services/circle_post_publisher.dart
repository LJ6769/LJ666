import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 上传媒体并写入 public."Post"。
abstract final class CirclePostPublisher {
  static const _postSelectQuery = '''
          id,
          content,
          author_id,
          media,
          created_at,
          User!author_id ( display_name, avatar_path, email )
        ''';

  static Future<CirclePost> publish({
    required String content,
    List<XFile> images = const [],
    XFile? video,
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not configured.');
    }
    if (!AuthService.isLoggedIn) {
      throw StateError('Please sign in to publish.');
    }

    final profile =
        AuthService.cachedProfile ?? await AuthService.loadCurrentProfile();
    if (profile == null) {
      throw StateError('Profile not found. Please sign in again.');
    }

    final trimmedContent = content.trim();
    final hasVideo = video != null;

    if (!hasVideo && images.isEmpty) {
      throw ArgumentError('Please add at least one image or a video.');
    }

    final mediaItems = hasVideo
        ? [
            await _uploadVideoMedia(
              client: client,
              authorId: profile.id,
              video: video,
            ),
          ]
        : await _uploadImageMedia(
            client: client,
            authorId: profile.id,
            images: images,
          );

    if (mediaItems.isEmpty) {
      throw StateError('Upload failed. Please try again.');
    }

    final postIndex = await _nextPostIndex(client);

    final row = await client
        .from(SupabaseTables.post)
        .insert({
          'author_id': profile.id,
          'post_index': postIndex,
          'content': trimmedContent,
          'media': mediaItems,
        })
        .select(_postSelectQuery)
        .single();

    FeedDataCache.invalidateCirclePosts();

    final post = await _mapInsertedPost(client, row);
    if (post == null) {
      throw StateError('Post saved but could not be loaded.');
    }
    return post;
  }

  static Future<int> _nextPostIndex(SupabaseClient client) async {
    final row = await client
        .from(SupabaseTables.post)
        .select('post_index')
        .order('post_index', ascending: false)
        .limit(1)
        .maybeSingle();
    final current = row?['post_index'];
    if (current is int) return current + 1;
    return 1;
  }

  static Future<List<Map<String, dynamic>>> _uploadImageMedia({
    required SupabaseClient client,
    required String authorId,
    required List<XFile> images,
  }) async {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < images.length; i++) {
      final file = File(images[i].path);
      if (!await file.exists()) continue;

      final ext = _imageExtension(images[i].path);
      final storagePath =
          'moments/posts/$authorId/${_uniqueBaseName()}.$ext';

      await client.storage.from(SupabaseConfig.mediaBucket).upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _imageContentType(ext),
            ),
          );

      items.add({
        'type': 'image',
        'storage_path': storagePath,
        'sort_order': i,
      });
    }
    return items;
  }

  static Future<Map<String, dynamic>> _uploadVideoMedia({
    required SupabaseClient client,
    required String authorId,
    required XFile video,
  }) async {
    final videoFile = File(video.path);
    if (!await videoFile.exists()) {
      throw StateError('Video file not found.');
    }

    final base = _uniqueBaseName();
    final videoPath = 'moments/posts/$authorId/$base.mp4';

    await client.storage.from(SupabaseConfig.mediaBucket).upload(
          videoPath,
          videoFile,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'video/mp4',
          ),
        );

    final posterPath = await _uploadVideoPoster(
      client: client,
      authorId: authorId,
      base: base,
      videoLocalPath: video.path,
    );

    return {
      'type': 'video',
      'storage_path': videoPath,
      'poster_path': posterPath,
      'sort_order': 0,
    };
  }

  static Future<String> _uploadVideoPoster({
    required SupabaseClient client,
    required String authorId,
    required String base,
    required String videoLocalPath,
  }) async {
    final posterPath = 'moments/posts/$authorId/${base}_poster.jpg';

    try {
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoLocalPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1280,
        quality: 85,
      );
      if (thumbPath != null) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          await client.storage.from(SupabaseConfig.mediaBucket).upload(
                posterPath,
                thumbFile,
                fileOptions: const FileOptions(
                  upsert: false,
                  contentType: 'image/jpeg',
                ),
              );
          return posterPath;
        }
      }
    } catch (error, stack) {
      debugPrint('[CirclePostPublisher] thumbnail failed: $error');
      debugPrint('$stack');
    }

    throw StateError('Could not generate video cover. Please try again.');
  }

  static Future<CirclePost?> _mapInsertedPost(
    SupabaseClient client,
    Map<String, dynamic> row,
  ) async {
    final mediaPaths = <String?>[];
    final profile = _readEmbeddedProfile(row['User']);
    mediaPaths.add(profile?['avatar_path'] as String?);

    final mediaRows = row['media'] as List<dynamic>? ?? [];
    for (final raw in mediaRows) {
      if (raw is! Map<String, dynamic>) continue;
      final type = raw['type'] as String? ?? 'image';
      if (type == 'video') {
        mediaPaths.add(raw['poster_path'] as String?);
        mediaPaths.add(raw['storage_path'] as String?);
      } else {
        mediaPaths.add(raw['storage_path'] as String?);
      }
    }

    final signed = await StorageMediaUrlResolver.resolveMany(
      mediaPaths,
      client: client,
    );

    return _mapPostRow(row, signed);
  }

  static CirclePost? _mapPostRow(
    Map<String, dynamic> map,
    Map<String, String> signed,
  ) {
    final mediaRows = map['media'] as List<dynamic>? ?? [];
    final sortedRows = [...mediaRows]
      ..sort((a, b) {
        final aOrder = (a as Map<String, dynamic>)['sort_order'] as int? ?? 0;
        final bOrder = (b as Map<String, dynamic>)['sort_order'] as int? ?? 0;
        return aOrder.compareTo(bOrder);
      });

    final profile = _readEmbeddedProfile(map['User']);
    final media = sortedRows
        .map((m) {
          final mm = m as Map<String, dynamic>;
          final type = mm['type'] as String? ?? 'image';
          final path = mm['storage_path'] as String?;
          final posterPath = mm['poster_path'] as String?;
          final isVideo = type == 'video';
          final displayPath = isVideo ? posterPath : path;
          final displayUrl =
              StorageMediaUrlResolver.pick(signed, displayPath);
          final posterUrl =
              StorageMediaUrlResolver.pickNullable(signed, posterPath);
          return CircleMedia(
            type: type,
            url: isVideo ? '' : displayUrl,
            posterUrl: posterUrl,
            displayPath: displayPath,
            videoPath: isVideo ? path : null,
          );
        })
        .where((m) => m.isVideo || m.previewUrl.isNotEmpty)
        .toList();

    if (media.isEmpty) return null;

    return CirclePost(
      id: map['id'] as String,
      content: (map['content'] as String? ?? '').trim(),
      authorId: map['author_id'] as String? ?? '',
      authorName: profile?['display_name'] as String? ?? 'Unknown',
      authorEmail: profile?['email'] as String?,
      authorAvatarUrl: StorageMediaUrlResolver.pickNullable(
        signed,
        profile?['avatar_path'] as String?,
      ),
      authorAvatarPath: profile?['avatar_path'] as String?,
      media: media,
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  static Map<String, dynamic>? _readEmbeddedProfile(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
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
