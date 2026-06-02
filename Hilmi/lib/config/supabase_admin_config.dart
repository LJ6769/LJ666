/// 本地 Python 脚本专用（勿在 App 中 import；未从 [config.dart] 导出）。
abstract final class SupabaseAdminConfig {
  static const serviceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjdXZ6ZXl1c2JtZndncm11Z291Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTc3NTA4NiwiZXhwIjoyMDk1MzUxMDg2fQ.F3mPLmWOBDxKCYplc6uYUydt__7Qxobz7ap6XawmDsg';

  /// 留空则部署脚本读终端环境变量 `SUPABASE_DB_PASSWORD`。
  static const dbPassword = '';

  static const poolerHost = 'aws-0-us-west-1.pooler.supabase.com:6543';
}
