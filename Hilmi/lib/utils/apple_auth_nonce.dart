import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Supabase Apple 登录所需的 nonce（明文给 Supabase，SHA256 给 Apple）。
String generateAppleAuthNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String sha256Nonce(String rawNonce) {
  final digest = sha256.convert(utf8.encode(rawNonce));
  return digest.toString();
}
