// 检测 JWT 因本机时钟偏差被拒（PGRST303）等。
import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST / Auth 因本机时钟快于服务器而拒绝 JWT（PGRST303）。
bool isJwtClockSkewError(Object error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST303') return true;
    final msg = error.message.toLowerCase();
    if (msg.contains('jwt issued at future')) return true;
  }
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('jwt issued at future')) return true;
  }
  return false;
}
