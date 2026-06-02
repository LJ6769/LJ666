/// 控制 Supabase 数据库与 Storage 出口量的策略（见 [config.dart] 统一导出）。
abstract final class SupabaseEgressConfig {
  /// 首页 / 朋友圈列表内存缓存时长（减少重复 select + 批量签名）。
  static const feedCacheTtl = Duration(minutes: 30);

  /// Signed URL 有效期（秒）；与 Storage 策略一致时可尽量拉长。
  static const signedUrlExpirySeconds = 604800;

  /// 距过期仍复用缓存的提前量（减少 createSignedUrls 调用）。
  static const signedUrlRefreshBeforeExpiry = Duration(hours: 48);
}
