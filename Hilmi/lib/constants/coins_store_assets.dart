/// 金币商城切图（`assets/coins_store/`）。
abstract final class CoinsStoreAssets {
  static const _base = 'assets/coins_store';

  /// 整页背景（558×1024，顶栏绿 + 下方浅绿花纹）。
  static const bgPage = '$_base/bg_page.png';
  static const bgPageWidth = 558.0;
  static const bgPageHeight = 1024.0;
  /// 背景纵向轻微拉伸（1.0 = 不拉伸）。
  static const bgPageStretchY = 1.12;
  static const btnBack = '$_base/btn_back.png';
  static const cardMyCoins = '$_base/card_my_coins.png';
  /// My Coins 条 @375 设计稿（pt）。
  static const cardMyCoinsDesignHeight = 74.0;
  static const cardMyCoinsDesignWidth = 456 / 210 * cardMyCoinsDesignHeight;
  /// 余额行相对切图（@375）。
  static const cardMyCoinsBalanceLeft = 0.48;
  static const cardMyCoinsAmountTop = 0.52;
  /// 小金币图标微调（@375 pt）：左移、与余额文字垂直居中。
  static const cardMyCoinsIconOffsetX = -6.0;
  static const cardMyCoinsIconOffsetY = 1.0;
  /// 余额文字「100k」左移（@375 pt）。
  static const cardMyCoinsAmountOffsetX = -4.0;

  /// 套餐格主图最大高度（@375）。
  static const pkgArtMaxHeight = 52.0;
  /// 购买按钮高度（@375）。
  static const priceBtnHeight = 28.0;
  /// 金币数量与购买按钮间距（@375）。
  static const priceBtnTopSpacing = 10.0;
  /// 购买按钮与卡片底边间距（@375）。
  static const priceBtnBottomSpacing = 9.0;
  /// 各档位价格按钮背景（浅金胶囊）。
  static const btnPrice = '$_base/btn_price.png';
  static const icCoin = '$_base/ic_coin.png';

  static const pkgCoinsFew = '$_base/pkg_coins_few.png';
  static const pkgCoinsStack = '$_base/pkg_coins_stack.png';
  static const pkgCoinsPile = '$_base/pkg_coins_pile.png';
  static const pkgCoinsBag = '$_base/pkg_coins_bag.png';
  static const pkgCoinsTrophy = '$_base/pkg_coins_trophy.png';
  static const pkgCoinsChest = '$_base/pkg_coins_chest.png';
  static const pkgCoinsChestOpen = '$_base/pkg_coins_chest_open.png';
  static const pkgCoinsLarge = '$_base/pkg_coins_large.png';
  static const pkgCoinsExtra = '$_base/pkg_coins_extra.png';
}
