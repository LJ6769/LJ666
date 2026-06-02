import 'package:flutter/foundation.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/utils/supabase_auth_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 用户金币读写（public."User".coins）。
class CoinsRepository {
  const CoinsRepository();

  /// 扣除金币，成功返回剩余余额。
  Future<int> spendCoins(int amount) async {
    if (!AuthService.isLoggedIn) {
      throw StateError('Not signed in');
    }

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not ready');
    }

    final cost = amount;
    if (cost <= 0) {
      throw ArgumentError('Amount must be positive');
    }

    try {
      final raw = await client.rpc(
        'spend_user_coins',
        params: {'p_amount': cost},
      );

      if (raw is! Map) {
        throw StateError('Spend coins failed');
      }

      final remaining = _readInt(Map<String, dynamic>.from(raw)['coins']);
      if (remaining == null) {
        throw StateError('Spend coins failed');
      }

      AuthService.patchCoins(remaining);
      return remaining;
    } on PostgrestException catch (error) {
      debugPrint('[CoinsRepository] spendCoins: ${error.message}');
      if (isJwtClockSkewError(error)) {
        await AuthService.clearAuthSession();
        throw StateError('Session expired. Please sign in again.');
      }
      final msg = error.message.toLowerCase();
      if (msg.contains('insufficient coins')) {
        throw StateError('Not enough coins');
      }
      if (msg.contains('not authenticated')) {
        throw StateError('Not signed in');
      }
      rethrow;
    }
  }

  /// 内购发货（服务端幂等：同一 transaction_id 只加币一次）。
  Future<int> grantFromPurchase({
    required String productId,
    required String transactionId,
  }) async {
    if (!AuthService.isLoggedIn) {
      throw StateError('Not signed in');
    }

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      throw StateError('Supabase is not ready');
    }

    final tx = transactionId.trim();
    if (tx.isEmpty) {
      throw StateError('Invalid transaction');
    }

    try {
      final raw = await client.rpc(
        'grant_coins_from_purchase',
        params: {
          'p_product_id': productId.trim(),
          'p_transaction_id': tx,
        },
      );

      final balance = _readInt(raw);
      if (balance == null) {
        throw StateError('Purchase fulfillment failed');
      }

      AuthService.patchCoins(balance);
      return balance;
    } on PostgrestException catch (error) {
      debugPrint('[CoinsRepository] grantFromPurchase: ${error.message}');
      if (isJwtClockSkewError(error)) {
        await AuthService.clearAuthSession();
        throw StateError('Session expired. Please sign in again.');
      }
      final msg = error.message.toLowerCase();
      if (msg.contains('unknown product')) {
        throw StateError('Unknown product. Please update the app.');
      }
      if (msg.contains('not authenticated')) {
        throw StateError('Not signed in');
      }
      rethrow;
    }
  }

  static int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }
}
