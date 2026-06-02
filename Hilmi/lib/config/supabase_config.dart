/// Supabase 客户端连接与 Storage（配置集中在 lib/config）。
abstract final class SupabaseConfig {
  static const projectRef = 'wcuvzeyusbmfwgrmugou';

  /// 不要带 `/rest/v1/` 后缀。
  static const url = 'https://wcuvzeyusbmfwgrmugou.supabase.co';

  /// Dashboard → Settings → API → anon public（客户端仅用此项）。
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjdXZ6ZXl1c2JtZndncm11Z291Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3NzUwODYsImV4cCI6MjA5NTM1MTA4Nn0.VCMT4FjH9_6FDgYsf1P0EZFP6bJJ8mqtzyRg4QmieqE';

  static const mediaBucket = 'media';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
