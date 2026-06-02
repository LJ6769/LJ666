/// App Store Connect 内购商品 ID 与到账金币（须与 Supabase `iap_coins_for_product` 一致）。
class IapStoreProduct {
  const IapStoreProduct({
    required this.productId,
    required this.coins,
  });

  final String productId;
  final int coins;
}

/// 内购与金币商城配置。
abstract final class IapConfig {
  /// 支付失败时统一提示（与商店未配置商品等场景共用）。
  static const String paymentFailureMessage = 'No product';

  /// 消耗型商品（与 App Store Connect 商品 ID 一致）。
  static const List<IapStoreProduct> storeProducts = [
    IapStoreProduct(productId: 'mgwtghzkyzayvhbw', coins: 400),
    IapStoreProduct(productId: 'ijwhpdnfcbtmhcsm', coins: 800),
    IapStoreProduct(productId: 'rsdzurddehlcrqzu', coins: 2450),
    IapStoreProduct(productId: 'unyqcpbgddjxgwwu', coins: 5150),
    IapStoreProduct(productId: 'sikxnzlzflsjwubp', coins: 10800),
    IapStoreProduct(productId: 'dncewabylvgxxify', coins: 29400),
    IapStoreProduct(productId: 'szhwifwbucazxgkf', coins: 63700),
  ];

  static Set<String> get allProductIds =>
      storeProducts.map((p) => p.productId).toSet();

  static int? coinsForProductId(String productId) {
    final id = productId.trim();
    for (final product in storeProducts) {
      if (product.productId == id) return product.coins;
    }
    return null;
  }

  static IapStoreProduct? productById(String productId) {
    final id = productId.trim();
    for (final product in storeProducts) {
      if (product.productId == id) return product;
    }
    return null;
  }
}
