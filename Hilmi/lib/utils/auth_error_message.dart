// 将 Supabase Auth 错误码转为用户可读文案。
import 'package:supabase_flutter/supabase_flutter.dart';

String messageFromAuthError(Object error) {
  if (error is AuthException) {
    return mapAuthErrorMessage(error.message);
  }
  if (error is StateError) {
    return mapAuthErrorMessage(error.message);
  }
  return mapAuthErrorMessage(error.toString());
}

String mapAuthErrorMessage(String message) {
  final lower = message.toLowerCase();

  if (lower.contains('email not confirmed') ||
      lower.contains('email_not_confirmed')) {
    return 'Email not verified. Please check your inbox or disable email confirmation in Supabase for development.';
  }
  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid credentials')) {
    return 'Incorrect email or password';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already been registered') ||
      lower.contains('already registered')) {
    return 'This email is already registered. Please sign in.';
  }
  if (lower.contains('not registered')) {
    return 'This email is not registered. Please sign up first.';
  }
  if (lower.contains('verify your email') ||
      lower.contains('check your email')) {
    return message;
  }
  if (lower.contains('rate limit') || lower.contains('too many requests')) {
    return 'Too many requests. Please try again later.';
  }
  if (lower.contains('supabase is not configured')) {
    return 'Supabase is not configured. Check lib/config/supabase_config.dart';
  }
  if (lower.contains('sign in with apple is only available')) {
    return 'Sign in with Apple is only available on iPhone, iPad, and Mac.';
  }
  if (lower.contains('apple sign in failed')) {
    return 'Apple sign in failed. Please try again.';
  }
  if (lower.contains('sign_in_with_apple') && lower.contains('cancel')) {
    return 'Apple sign in was canceled.';
  }
  if (lower.contains('user_apple_user_id_key') ||
      (lower.contains('apple_user_id') &&
          (lower.contains('duplicate') || lower.contains('23505')))) {
    return 'This Apple account is already registered. Please try Apple sign in again.';
  }

  return message;
}
