// 直播间礼物商城底部弹层。
import 'package:flutter/material.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/data/coins_repository.dart';
import 'package:hilmi/utils/open_coins_store.dart';
import 'package:hilmi/models/live_gift_send_result.dart';
import 'package:hilmi/utils/format_coins.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

/// 直播间礼物商城底部弹层（点击礼物按钮打开）。
class LiveGiftShopSheet extends StatefulWidget {
  const LiveGiftShopSheet({
    super.key,
    required this.scale,
    this.initialCoinBalance = UserConfig.guestBalance,
  });

  final double scale;
  final int initialCoinBalance;

  static const _designWidth = 375.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static Future<LiveGiftSendResult?> show(
    BuildContext context, {
    int initialCoinBalance = UserConfig.guestBalance,
  }) async {
    final balance = AuthService.isLoggedIn
        ? (AuthService.cachedProfile?.coins ?? initialCoinBalance)
        : initialCoinBalance;
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    return showModalBottomSheet<LiveGiftSendResult?>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => LiveGiftShopSheet(
        scale: scale,
        initialCoinBalance: balance,
      ),
    );
  }

  @override
  State<LiveGiftShopSheet> createState() => _LiveGiftShopSheetState();
}

class _LiveGiftShopSheetState extends State<LiveGiftShopSheet> {
  /// 顶栏关闭按钮高度（与金币条分开，避免金币条加高时 X 一起变大）。
  static const _closeButtonHeightDesign = 40.0;

  static final _gifts = <_GiftItem>[
    _GiftItem(id: 'bottle', icon: LiveRoomAssets.giftBottle, price: 20),
    _GiftItem(id: 'candy', icon: LiveRoomAssets.giftCandy, price: 20),
    _GiftItem(id: 'juice', icon: LiveRoomAssets.giftJuice, price: 20),
    _GiftItem(
      id: 'cocktail_green',
      icon: LiveRoomAssets.giftCocktailGreen,
      price: 20,
    ),
    _GiftItem(id: 'martini', icon: LiveRoomAssets.giftMartini, price: 20),
    _GiftItem(
      id: 'cocktail_hug',
      icon: LiveRoomAssets.giftCocktailHug,
      price: 20,
    ),
    _GiftItem(id: 'cup', icon: LiveRoomAssets.giftCup, price: 20),
    _GiftItem(id: 'soda', icon: LiveRoomAssets.giftSoda, price: 20),
  ];

  late int _coinBalance;
  bool _sending = false;
  final _coinsRepository = const CoinsRepository();

  double get _s => widget.scale;

  @override
  void initState() {
    super.initState();
    _coinBalance = widget.initialCoinBalance;
  }

  Future<void> _onRechargeTap() async {
    await openCoinsStore(context);
    if (!mounted) return;
    await AuthService.loadCurrentProfile();
    if (!mounted) return;
    setState(() {
      _coinBalance = AuthService.cachedProfile?.coins ?? _coinBalance;
    });
  }

  Future<void> _onSendGift(_GiftItem gift) async {
    if (_sending) return;

    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to send gifts')) {
      return;
    }
    if (!mounted) return;

    final balance = AuthService.cachedProfile?.coins ?? _coinBalance;
    if (balance < gift.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final remaining = await _coinsRepository.spendCoins(gift.price);
      if (!mounted) return;
      setState(() => _coinBalance = remaining);
      Navigator.of(context).pop(
        LiveGiftSendResult(
          giftId: gift.id,
          giftIconAsset: gift.icon,
          price: gift.price,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message =
          error is StateError ? error.message : 'Could not send gift: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(top: 56 * _s),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.only(bottom: bottomPad + 4 * _s),
          decoration: BoxDecoration(
            color: LiveGiftShopSheet._panelColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20 * _s)),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildGiftGrid(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader() {
    final closeHeight = _closeButtonHeightDesign * _s;

    return Padding(
      padding: EdgeInsets.fromLTRB(16 * _s, 12 * _s, 12 * _s, 28 * _s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            LiveRoomAssets.giftShopTitle,
            height: 30 * _s,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _CoinBalanceBar(
                  scale: _s,
                  coins: _coinBalance,
                  onRecharge: _onRechargeTap,
                ),
              ),
            ),
          ),
          SizedBox(width: 10 * _s),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              LiveRoomAssets.giftShopClose,
              height: closeHeight,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14 * _s, 3 * _s, 14 * _s, 10 * _s),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 210 * _s),
        child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12 * _s,
          crossAxisSpacing: 10 * _s,
          childAspectRatio: 0.72,
        ),
        itemCount: _gifts.length,
        itemBuilder: (context, index) {
          final gift = _gifts[index];
          return _GiftCell(
            scale: _s,
            iconAsset: gift.icon,
            price: gift.price,
            enabled: !_sending,
            onSend: () => _onSendGift(gift),
          );
        },
      ),
      ),
    );
  }
}

class _CoinBalanceBar extends StatelessWidget {
  const _CoinBalanceBar({
    required this.scale,
    required this.coins,
    required this.onRecharge,
  });

  /// 金币条高度（略高于原 40，背景切图 @1x 高 108 会随 BoxFit.fill 拉伸）。
  static const barHeightDesign = 52.0;

  /// 充值「+」按钮尺寸（切图 @1x 75×75）。
  static const rechargeIconDesign = 32.0;

  final double scale;
  final int coins;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final height = barHeightDesign * s;
    final horizontalPad = 14 * s;

    return IntrinsicWidth(
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: Image.asset(
                LiveRoomAssets.giftShopBalanceBg,
                fit: BoxFit.fill,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    LiveRoomAssets.giftShopCoin,
                    height: 22 * s,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 6 * s),
                  Text(
                    formatCompactCoins(coins),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15 * s,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  SizedBox(width: 8 * s),
                  GestureDetector(
                    onTap: onRecharge,
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      LiveRoomAssets.giftShopRecharge,
                      height: rechargeIconDesign * s,
                      width: rechargeIconDesign * s,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftItem {
  const _GiftItem({
    required this.id,
    required this.icon,
    required this.price,
  });

  final String id;
  final String icon;
  final int price;
}

class _GiftCell extends StatelessWidget {
  const _GiftCell({
    required this.scale,
    required this.iconAsset,
    required this.price,
    required this.enabled,
    required this.onSend,
  });

  final double scale;
  final String iconAsset;
  final int price;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        border: Border.all(color: Colors.black, width: 2),
      ),
      padding: EdgeInsets.fromLTRB(4 * s, 6 * s, 4 * s, 6 * s),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: 2 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                LiveRoomAssets.giftShopCoin,
                width: 14 * s,
                height: 14 * s,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 2 * s),
              Flexible(
                child: Text(
                  '$price',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11 * s,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * s),
          GestureDetector(
            onTap: enabled ? onSend : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: double.infinity,
              height: 28 * s,
              child: Image.asset(
                LiveRoomAssets.giftShopSend,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
