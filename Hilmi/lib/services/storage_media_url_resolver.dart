import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/utils/media_url.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _CachedSignedUrl {
  _CachedSignedUrl({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final DateTime expiresAt;
}

/// 私有 Storage bucket 的 Signed URL 缓存。
abstract final class StorageMediaUrlResolver {
  StorageMediaUrlResolver._();

  static const defaultExpirySeconds =
      SupabaseEgressConfig.signedUrlExpirySeconds;
  static const _refreshBeforeExpiry =
      SupabaseEgressConfig.signedUrlRefreshBeforeExpiry;

  static final _cache = <String, _CachedSignedUrl>{};
  static final _knownMissing = <String>{};
  static final _loggedMissingCanonical = <String>{};

  static void clearCache() {
    _cache.clear();
    _knownMissing.clear();
    _loggedMissingCanonical.clear();
  }

  /// 对象已更新（如换头像）时丢弃旧 Signed URL，避免继续命中过期缓存。
  static void invalidate(String? objectPath) {
    final normalized = _normalize(objectPath);
    if (normalized.isEmpty) return;

    for (final path in storagePathCandidates(normalized)) {
      _cache.remove(path);
      _knownMissing.remove(path);
    }
    _loggedMissingCanonical.remove(normalized);
  }

  static String lookup(String? objectPath) {
    final normalized = _normalize(objectPath);
    if (normalized.isEmpty) return '';
    final url = _cache[normalized]?.url ?? '';
    return isValidSignedMediaUrl(url) ? url : '';
  }

  static bool isValidSignedMediaUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed.endsWith('null')) return false;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    return trimmed.contains('/object/sign/');
  }

  static Future<String> resolve(
    String? objectPath, {
    SupabaseClient? client,
    int expiresIn = defaultExpirySeconds,
  }) async {
    final normalized = _normalize(objectPath);
    if (normalized.isEmpty) return '';

    final cached = _cache[normalized];
    if (cached != null &&
        cached.expiresAt.isAfter(
          DateTime.now().add(_refreshBeforeExpiry),
        )) {
      return cached.url;
    }

    final signed =
        await resolveMany([normalized], client: client, expiresIn: expiresIn);
    final url = signed[normalized] ?? '';
    return isValidSignedMediaUrl(url) ? url : '';
  }

  static Future<Map<String, String>> resolveMany(
    Iterable<String?> rawPaths, {
    SupabaseClient? client,
    int expiresIn = defaultExpirySeconds,
  }) async {
    final canonicals = <String>[];
    final candidateByCanonical = <String, List<String>>{};
    final pathsToSign = <String>{};

    for (final raw in rawPaths) {
      final canonical = _normalize(raw);
      if (canonical.isEmpty) continue;

      final candidates = storagePathCandidates(canonical);
      if (candidates.every(_knownMissing.contains)) continue;

      canonicals.add(canonical);
      candidateByCanonical[canonical] = candidates;
      pathsToSign.addAll(candidates);
    }

    if (canonicals.isEmpty) return const {};

    final signedByPath = await _signPathsBatch(
      pathsToSign,
      client: client,
      expiresIn: expiresIn,
    );

    final result = <String, String>{};
    var missingCanonical = 0;

    for (final canonical in canonicals) {
      var resolved = false;
      for (final candidate in candidateByCanonical[canonical]!) {
        final url = signedByPath[candidate];
        if (url != null && url.isNotEmpty) {
          result[canonical] = url;
          final cached = _cache[candidate];
          if (cached != null) {
            _cache[canonical] = cached;
          }
          resolved = true;
          break;
        }
      }
      if (!resolved) {
        missingCanonical++;
        for (final candidate in candidateByCanonical[canonical]!) {
          _knownMissing.add(candidate);
        }
        _logMissingOnce(canonical);
      }
    }

    if (missingCanonical > 0 && missingCanonical <= 3) {
      debugPrint(
        '[StorageMediaUrlResolver] $missingCanonical asset(s) missing in Storage; '
        'run locally: python3 scripts/upload_media.py --with-videos',
      );
    } else if (missingCanonical > 3) {
      debugPrint(
        '[StorageMediaUrlResolver] $missingCanonical asset(s) missing; '
        'run: python3 scripts/upload_media.py --with-videos',
      );
    }

    return result;
  }

  static Future<Map<String, String>> _signPathsBatch(
    Set<String> paths, {
    SupabaseClient? client,
    required int expiresIn,
  }) async {
    final result = <String, String>{};
    final toRequest = <String>[];

    for (final path in paths) {
      if (_knownMissing.contains(path)) continue;

      final cached = _cache[path];
      if (cached != null &&
          cached.expiresAt.isAfter(
            DateTime.now().add(_refreshBeforeExpiry),
          )) {
        result[path] = cached.url;
      } else {
        toRequest.add(path);
      }
    }

    if (toRequest.isEmpty) return result;

    final c = client ?? AppBootstrap.client;
    if (c == null || !AppBootstrap.isReady) {
      debugPrint(
        '[StorageMediaUrlResolver] Supabase not ready; cannot sign ${toRequest.length} path(s)',
      );
      return result;
    }

    try {
      final signed = await c.storage
          .from(SupabaseConfig.mediaBucket)
          .createSignedUrls(toRequest, expiresIn);

      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      for (final item in signed) {
        final path = _normalize(item.path);
        final url = item.signedUrl.trim();
        if (path.isEmpty || !isValidSignedMediaUrl(url)) continue;

        _cache[path] = _CachedSignedUrl(url: url, expiresAt: expiresAt);
        result[path] = url;
      }
    } catch (error, stack) {
      debugPrint('[StorageMediaUrlResolver] createSignedUrls failed: $error');
      debugPrint('$stack');
    }

    return result;
  }

  static void _logMissingOnce(String canonical) {
    if (!_loggedMissingCanonical.add(canonical)) return;
    if (canonical.contains('/poster.')) return;
    debugPrint('[StorageMediaUrlResolver] File not in Storage: $canonical');
  }

  static String pick(Map<String, String> signed, String? objectPath) {
    final normalized = _normalize(objectPath);
    if (normalized.isEmpty) return '';
    return signed[normalized] ?? '';
  }

  static String? pickNullable(Map<String, String> signed, String? objectPath) {
    final url = pick(signed, objectPath);
    return url.isEmpty ? null : url;
  }

  /// 列表展示：视频签 poster 封面，图片签 storage_path。
  static Iterable<String?> displayPathsForPostMedia(
    List<dynamic>? mediaRows,
  ) sync* {
    for (final raw in mediaRows ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      final type = raw['type'] as String? ?? 'image';
      if (type == 'video') {
        yield raw['poster_path'] as String?;
      } else {
        yield raw['storage_path'] as String?;
      }
    }
  }

  static String _normalize(String? objectPath) {
    if (objectPath == null || objectPath.isEmpty) return '';
    final trimmed = objectPath.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return normalizeStorageObjectPath(trimmed);
  }
}
