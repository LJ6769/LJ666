// 金币商城 UI 目录条目（配图、文案；支付见 iap_config）。
import 'package:hilmi/config/iap_config.dart';
import 'package:hilmi/constants/coins_store_assets.dart';

/// 金币商城展示条目（商品 ID / 金币数以 [IapConfig.storeProducts] 为准）。
class IapProductCatalogEntry {
  const IapProductCatalogEntry({
    required this.productId,
    required this.coins,
    required this.fallbackPrice,
    required this.art,
    this.priceBtn = CoinsStoreAssets.btnPrice,
  });

  final String productId;
  final int coins;
  final String fallbackPrice;
  final String art;
  final String priceBtn;
}

/// 内购商城 UI 目录（价格文案、配图；支付逻辑见 [IapConfig]）。
abstract final class IapCatalogConfig {
  static const paymentFailureMessage = IapConfig.paymentFailureMessage;

  static const catalog = <IapProductCatalogEntry>[
    IapProductCatalogEntry(
      productId: 'mgwtghzkyzayvhbw',
      coins: 400,
      fallbackPrice: r'$0.99',
      art: CoinsStoreAssets.pkgCoinsFew,
    ),
    IapProductCatalogEntry(
      productId: 'ijwhpdnfcbtmhcsm',
      coins: 800,
      fallbackPrice: r'$1.99',
      art: CoinsStoreAssets.pkgCoinsStack,
    ),
    IapProductCatalogEntry(
      productId: 'rsdzurddehlcrqzu',
      coins: 2450,
      fallbackPrice: r'$4.99',
      art: CoinsStoreAssets.pkgCoinsPile,
    ),
    IapProductCatalogEntry(
      productId: 'unyqcpbgddjxgwwu',
      coins: 5150,
      fallbackPrice: r'$9.99',
      art: CoinsStoreAssets.pkgCoinsBag,
    ),
    IapProductCatalogEntry(
      productId: 'sikxnzlzflsjwubp',
      coins: 10800,
      fallbackPrice: r'$19.99',
      art: CoinsStoreAssets.pkgCoinsTrophy,
    ),
    IapProductCatalogEntry(
      productId: 'dncewabylvgxxify',
      coins: 29400,
      fallbackPrice: r'$49.99',
      art: CoinsStoreAssets.pkgCoinsChest,
    ),
    IapProductCatalogEntry(
      productId: 'szhwifwbucazxgkf',
      coins: 63700,
      fallbackPrice: r'$99.99',
      art: CoinsStoreAssets.pkgCoinsChestOpen,
    ),
  ];

  static Set<String> get allProductIds => IapConfig.allProductIds;

  static IapProductCatalogEntry? byProductId(String id) {
    final trimmed = id.trim();
    for (final entry in catalog) {
      if (entry.productId == trimmed) return entry;
    }
    return null;
  }
}
