// Storage 路径编码、公开 URL 与 cacheKey 提取工具。
import 'package:hilmi/config/config.dart';

/// 对 Storage 路径逐段 URL 编码（支持中文文件名、空格）。
String encodeStoragePath(String path) {
  return path
      .split('/')
      .map((segment) => Uri.encodeComponent(segment))
      .join('/');
}

/// 生成 Supabase Storage 公开访问 URL（仅当 bucket 为 public 时有效）。
/// 应用内请使用 [StorageMediaUrlResolver.resolve]。
@Deprecated('Use StorageMediaUrlResolver.resolve for private buckets')
String publicMediaUrl(String objectPath) {
  if (objectPath.isEmpty) return '';
  final base = SupabaseConfig.url.replaceAll(RegExp(r'/$'), '');
  final normalized = normalizeStorageObjectPath(objectPath);
  final encoded = encodeStoragePath(normalized);
  return '$base/storage/v1/object/public/${SupabaseConfig.mediaBucket}/$encoded';
}

/// 将数据库 storage 路径转为公开 URL（私有桶下无效）。
@Deprecated('Use StorageMediaUrlResolver.resolve')
String resolveStoragePublicUrl(String? objectPath) {
  if (objectPath == null || objectPath.isEmpty) return '';
  final trimmed = objectPath.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return publicMediaUrl(trimmed);
}

/// 同一资源在 DB 与 [upload_media.py] 上传结果之间的路径变体。
List<String> storagePathCandidates(String? objectPath) {
  final normalized = normalizeStorageObjectPath(objectPath?.trim() ?? '');
  if (normalized.isEmpty) return const [];

  final candidates = <String>{normalized};
  for (final alt in _legacyStoragePathAliases(normalized)) {
    candidates.add(alt);
  }
  return candidates.toList();
}

/// 种子数据含 `_副本`，上传脚本会转为 `_copy`（见 fix_user_rls / storage_safe_filename）。
List<String> _legacyStoragePathAliases(String path) {
  final out = <String>[];
  if (path.contains('_副本.')) {
    out.add(path.replaceAll('_副本.', '_copy.'));
  }
  if (path.contains('_copy.')) {
    out.add(path.replaceAll('_copy.', '_副本.'));
  }
  if (path.contains('副本')) {
    final replaced = path.replaceAll('副本', 'copy');
    if (replaced != path) out.add(replaced);
  }
  return out;
}

/// 从 Signed / Public Storage URL 提取对象路径，用作 [CachedNetworkImage.cacheKey]。
String? storagePathFromMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final trimmed = url.trim();
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    return normalizeStorageObjectPath(trimmed);
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  final path = uri.path;
  final signMarker = '/object/sign/${SupabaseConfig.mediaBucket}/';
  final publicMarker = '/object/public/${SupabaseConfig.mediaBucket}/';

  for (final marker in [signMarker, publicMarker]) {
    final idx = path.indexOf(marker);
    if (idx >= 0) {
      final objectPath = path.substring(idx + marker.length);
      final normalized = normalizeStorageObjectPath(objectPath);
      return normalized.isEmpty ? null : normalized;
    }
  }

  return null;
}

/// 去掉首尾斜杠及误存的 bucket 前缀。
String normalizeStorageObjectPath(String path) {
  var p = path.trim().replaceFirst(RegExp(r'^/'), '');
  final publicPrefix =
      'storage/v1/object/public/${SupabaseConfig.mediaBucket}/';
  final signedPrefix =
      'storage/v1/object/sign/${SupabaseConfig.mediaBucket}/';
  for (final prefix in [publicPrefix, signedPrefix]) {
    final idx = p.indexOf(prefix);
    if (idx >= 0) {
      p = p.substring(idx + prefix.length);
      break;
    }
  }
  const legacyPrefix = 'hilmi/';
  if (p.startsWith(legacyPrefix)) {
    p = p.substring(legacyPrefix.length);
  }
  return p;
}
