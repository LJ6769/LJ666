import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/constants/coins_store_assets.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/services/iap_purchase_service.dart';
import 'package:hilmi/utils/format_coins.dart';

/// 金币商城（首页 / 消息页金币旁 + 进入）。
class CoinsStoreScreen extends StatefulWidget {
  const CoinsStoreScreen({super.key});

  @override
  State<CoinsStoreScreen> createState() => _CoinsStoreScreenState();
}

class _CoinsStoreScreenState extends State<CoinsStoreScreen> {
  static const _designWidth = 375.0;
  static const _gridHPadding = 20.0;
  static const _gridSpacing = 10.0;
  /// 套餐格宽/高（设计稿约 108×118pt）。
  static const _cellAspectRatio = 0.84;

  final _iap = IapPurchaseService.instance;
  String? _purchasingProductId;
  bool _iapReady = false;

  double _scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / _designWidth;

  int get _coins => AuthService.cachedProfile?.coins ?? 0;

  @override
  void initState() {
    super.initState();
    _iap.onUiEvent = _onIapUiEvent;
    _initIap();
  }

  @override
  void dispose() {
    if (_iap.onUiEvent == _onIapUiEvent) {
      _iap.onUiEvent = null;
    }
    super.dispose();
  }

  Future<void> _initIap() async {
    await _iap.initialize();
    if (!mounted) return;
    setState(() => _iapReady = _iap.isAvailable);
  }

  void _onIapUiEvent(IapPurchaseUiEvent event) {
    if (!mounted) return;
    switch (event) {
      case IapPurchasePending(:final productId):
        setState(() => _purchasingProductId = productId);
      case IapPurchaseSuccess(:final coins):
        setState(() {
          _purchasingProductId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$coins coins added successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case IapPurchaseFailed(:final message):
        setState(() => _purchasingProductId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case IapPurchaseCanceled():
        setState(() => _purchasingProductId = null);
    }
  }

  Future<void> _onPurchaseTap(IapProductCatalogEntry entry) async {
    if (_purchasingProductId != null) return;

    if (!AuthService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to purchase coins'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_iap.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(IapCatalogConfig.paymentFailureMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final started = await _iap.purchase(entry.productId);
    if (!started && mounted && _purchasingProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(IapCatalogConfig.paymentFailureMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scale(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hPad = _gridHPadding * scale;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                CoinsStoreAssets.bgPage,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 6 * scale, hPad, 20 * scale),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 40 * scale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  behavior: HitTestBehavior.opaque,
                                  child: Image.asset(
                                    CoinsStoreAssets.btnBack,
                                    width: 36 * scale,
                                    height: 36 * scale,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Text(
                                'Coins Store',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10 * scale),
                          child: _MyCoinsCard(scale: scale, coins: _coins),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      20 * scale,
                      hPad,
                      bottomInset + 12 * scale,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: _gridSpacing * scale,
                      crossAxisSpacing: _gridSpacing * scale,
                      childAspectRatio: _cellAspectRatio,
                    ),
                    itemCount: IapCatalogConfig.catalog.length,
                    itemBuilder: (context, index) {
                      final entry = IapCatalogConfig.catalog[index];
                      final price = _iap.displayPrice(
                        entry.productId,
                        entry.fallbackPrice,
                      );
                      final purchasing =
                          _purchasingProductId == entry.productId;
                      return _PackageCell(
                        scale: scale,
                        coins: entry.coins,
                        price: price,
                        art: entry.art,
                        priceBtn: entry.priceBtn,
                        purchasing: purchasing,
                        enabled: _iapReady && _purchasingProductId == null,
                        onTap: () => _onPurchaseTap(entry),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_iap.isQuerying && !_iapReady)
              const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyCoinsCard extends StatelessWidget {
  const _MyCoinsCard({required this.scale, required this.coins});

  final double scale;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final h = CoinsStoreAssets.cardMyCoinsDesignHeight * s;
    final w = CoinsStoreAssets.cardMyCoinsDesignWidth * s;

    return Center(
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              CoinsStoreAssets.cardMyCoins,
              width: w,
              height: h,
              fit: BoxFit.contain,
            ),
            Positioned(
              left: w * CoinsStoreAssets.cardMyCoinsBalanceLeft,
              top: h * CoinsStoreAssets.cardMyCoinsAmountTop,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(
                      CoinsStoreAssets.cardMyCoinsIconOffsetX * s,
                      CoinsStoreAssets.cardMyCoinsIconOffsetY * s,
                    ),
                    child: Image.asset(
                      CoinsStoreAssets.icCoin,
                      width: 16 * s,
                      height: 16 * s,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 3 * s),
                  Transform.translate(
                    offset: Offset(CoinsStoreAssets.cardMyCoinsAmountOffsetX * s, 0),
                    child: Text(
                      formatCompactCoins(coins),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15 * s,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
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

class _PackageCell extends StatelessWidget {
  const _PackageCell({
    required this.scale,
    required this.coins,
    required this.price,
    required this.art,
    required this.priceBtn,
    required this.purchasing,
    required this.enabled,
    required this.onTap,
  });

  final double scale;
  final int coins;
  final String price;
  final String art;
  final String priceBtn;
  final bool purchasing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    const borderW = 1.5;
    final artH = CoinsStoreAssets.pkgArtMaxHeight * s;
    final btnH = CoinsStoreAssets.priceBtnHeight * s;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled || purchasing ? 1 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10 * s),
            border: Border.all(color: Colors.black, width: borderW),
          ),
          padding: EdgeInsets.fromLTRB(
            5 * s,
            8 * s,
            5 * s,
            CoinsStoreAssets.priceBtnBottomSpacing * s,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: artH,
                width: double.infinity,
                child: Center(
                  child: Image.asset(
                    art,
                    height: artH,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: 2 * s),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    CoinsStoreAssets.icCoin,
                    width: 12 * s,
                    height: 12 * s,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 2 * s),
                  Text(
                    formatCompactCoins(coins),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: CoinsStoreAssets.priceBtnTopSpacing * s),
              SizedBox(
                height: btnH,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        priceBtn,
                        fit: BoxFit.fill,
                      ),
                    ),
                    if (purchasing)
                      SizedBox(
                        width: 16 * s,
                        height: 16 * s,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    else
                      Text(
                        price,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12 * s,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
