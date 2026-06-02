import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/utils/format_coins.dart';
import 'package:hilmi/utils/open_coins_store.dart';

/// 顶栏金币余额 + 「+」充值入口（首页 Discover / 消息页共用）。
class CoinBalanceBar extends StatefulWidget {
  const CoinBalanceBar({
    super.key,
    required this.coinBalance,
    this.borderWidth = 3,
  });

  /// 未登录时的展示余额；登录后以 [AuthService.cachedProfile] 为准。
  final int coinBalance;
  final double borderWidth;

  @override
  State<CoinBalanceBar> createState() => _CoinBalanceBarState();
}

class _CoinBalanceBarState extends State<CoinBalanceBar> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    AuthService.coinsNotifier.addListener(_onCoinsChanged);
    _authSubscription = AuthService.onAuthStateChange.listen((_) {
      unawaited(_syncFromProfile());
    });
  }

  @override
  void dispose() {
    AuthService.coinsNotifier.removeListener(_onCoinsChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onCoinsChanged() {
    if (mounted) setState(() {});
  }

  int get _displayBalance {
    if (AuthService.isLoggedIn) {
      return AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;
    }
    return widget.coinBalance;
  }

  Future<void> _syncFromProfile() async {
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openStore() async {
    await openCoinsStore(context);
    await _syncFromProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black, width: widget.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/home/coin.png', width: 28, height: 28),
          const SizedBox(width: 6),
          Text(
            formatCompactCoins(_displayBalance),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openStore,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              'assets/home/btn_add.png',
              width: 28,
              height: 28,
            ),
          ),
        ],
      ),
    );
  }
}
