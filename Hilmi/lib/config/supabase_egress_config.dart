/// 控制 Supabase 数据库与 Storage 出口量的策略（见 [config.dart] 统一导出）。
abstract final class SupabaseEgressConfig {
  /// 首页 / Bartending Live 列表本地缓存时长。
  static const feedCacheTtl = Duration(days: 30);

  /// 朋友圈列表本地缓存时长。
  static const circleCacheTtl = Duration(days: 30);

  /// 个人中心 My Post / My Like 本地缓存时长。
  static const profilePostsCacheTtl = Duration(days: 30);

  /// Supabase 图片/视频磁盘缓存时长（原文件，不压缩）。
  static const mediaCacheTtl = Duration(days: 30);

  /// Signed URL 有效期（秒）；与 [mediaCacheTtl] 对齐，减少重复签名请求。
  static const signedUrlExpirySeconds = 2592000;

  /// 距过期仍复用签名缓存的提前量。
  static const signedUrlRefreshBeforeExpiry = Duration(days: 1);
}
