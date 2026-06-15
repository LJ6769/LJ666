// 金币商城页：余额展示与 IAP 套餐购买。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/constants/coins_store_assets.dart';
import 'package:hilmi/controllers/coins_store_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/utils/format_coins.dart';

/// 金币商城（首页 / 消息页金币旁 + 进入）。
class CoinsStoreScreen extends StatelessWidget {
  const CoinsStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetxScreen<CoinsStoreController>(
      create: CoinsStoreController.new,
      builder: (c) => Obx(() {
        final scale = c.scale(context);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final hPad = CoinsStoreController.gridHPadding * scale;
        final iapReady = c.iapReady.value;
        final purchasingProductId = c.purchasingProductId.value;

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
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          6 * scale,
                          hPad,
                          20 * scale,
                        ),
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
                              child: _MyCoinsCard(scale: scale, coins: c.coins),
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
                          mainAxisSpacing: CoinsStoreController.gridSpacing * scale,
                          crossAxisSpacing: CoinsStoreController.gridSpacing * scale,
                          childAspectRatio: CoinsStoreController.cellAspectRatio,
                        ),
                        itemCount: IapCatalogConfig.catalog.length,
                        itemBuilder: (context, index) {
                          final entry = IapCatalogConfig.catalog[index];
                          final price = c.displayPrice(
                            entry.productId,
                            entry.fallbackPrice,
                          );
                          final purchasing =
                              purchasingProductId == entry.productId;
                          return _PackageCell(
                            scale: scale,
                            coins: entry.coins,
                            price: price,
                            art: entry.art,
                            priceBtn: entry.priceBtn,
                            purchasing: purchasing,
                            enabled: iapReady && purchasingProductId == null,
                            onTap: () => c.onPurchaseTap(context, entry),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (c.isQuerying && !iapReady)
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        );
      }),
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
