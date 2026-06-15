// 消耗型内购：查询、购买、发货后 completePurchase。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/data/coins_repository.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// 消耗型内购：查询商品、发起购买、发货后 completePurchase。
class IapPurchaseService {
  IapPurchaseService._();

  static final IapPurchaseService instance = IapPurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final CoinsRepository _coinsRepository = const CoinsRepository();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _initialized = false;
  bool _available = false;
  bool _querying = false;

  final Map<String, ProductDetails> _storeProducts = {};
  final Set<String> _processedPurchaseKeys = {};
  final Set<String> _inFlightPurchaseKeys = {};

  void Function(IapPurchaseUiEvent event)? onUiEvent;

  bool get isAvailable => _available;
  bool get isQuerying => _querying;
  Map<String, ProductDetails> get storeProducts => Map.unmodifiable(_storeProducts);

  String displayPrice(String productId, String fallback) {
    return _storeProducts[productId]?.price ?? fallback;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!await _iap.isAvailable()) {
      _available = false;
      debugPrint('[IapPurchaseService] Store not available on this device');
      return;
    }

    _available = true;
    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error, StackTrace stack) {
        debugPrint('[IapPurchaseService] purchaseStream error: $error');
        debugPrint('$stack');
        _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
      },
    );

    // 消耗型金币勿调用 restorePurchases：会把未完成的旧订单再投递一次，
    // 容易与本次购买叠加（同一 transaction 重复投递会双倍到账）。
    await queryProducts();
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
    _available = false;
    _storeProducts.clear();
    _processedPurchaseKeys.clear();
    _inFlightPurchaseKeys.clear();
  }

  Future<void> queryProducts() async {
    if (!_available) return;
    _querying = true;
    try {
      final response = await _iap.queryProductDetails(IapCatalogConfig.allProductIds);
      if (response.error != null) {
        debugPrint(
          '[IapPurchaseService] queryProductDetails: ${response.error}',
        );
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          '[IapPurchaseService] Products not found in store: ${response.notFoundIDs}',
        );
      }
      _storeProducts
        ..clear()
        ..addEntries(
          response.productDetails.map((p) => MapEntry(p.id, p)),
        );
    } finally {
      _querying = false;
    }
  }

  Future<bool> purchase(String productId) async {
    if (!_available) {
      _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
      return false;
    }
    if (!AuthService.isLoggedIn) {
      _emit(IapPurchaseUiEvent.failed('Please sign in to purchase coins.'));
      return false;
    }

    final details = _storeProducts[productId];
    if (details == null) {
      _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
      return false;
    }

    _emit(IapPurchaseUiEvent.pending(productId));
    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) {
        _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
      }
      return started;
    } catch (error, stack) {
      debugPrint('[IapPurchaseService] buyConsumable: $error');
      debugPrint('$stack');
      _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
      return false;
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;

    switch (purchase.status) {
      case PurchaseStatus.pending:
        _emit(IapPurchaseUiEvent.pending(productId));
        return;
      case PurchaseStatus.error:
        if (purchase.error != null) {
          debugPrint('[IapPurchaseService] purchase error: ${purchase.error}');
        }
        _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        return;
      case PurchaseStatus.canceled:
        _emit(IapPurchaseUiEvent.canceled());
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        break;
    }

    final key = _purchaseKey(purchase);
    if (_processedPurchaseKeys.contains(key) || _inFlightPurchaseKeys.contains(key)) {
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    final transactionId = purchase.purchaseID?.trim() ?? '';
    if (transactionId.isEmpty) {
      _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    _inFlightPurchaseKeys.add(key);
    try {
      final coinsBefore = AuthService.cachedProfile?.coins ?? 0;
      final balance = await _coinsRepository.grantFromPurchase(
        productId: productId,
        transactionId: transactionId,
      );
      _processedPurchaseKeys.add(key);
      AuthService.patchCoins(balance);

      final entry = IapCatalogConfig.byProductId(productId);
      final catalogCoins = entry?.coins ?? 0;
      final granted = balance - coinsBefore;
      final coinsAdded = granted > 0 ? granted : catalogCoins;

      // 服务端幂等：重复 transaction 时 granted 为 0，不再弹成功提示。
      if (granted > 0) {
        _emit(
          IapPurchaseUiEvent.success(
            productId: productId,
            coins: coinsAdded,
            balance: balance,
          ),
        );
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    } catch (error, stack) {
      debugPrint('[IapPurchaseService] grant coins: $error');
      debugPrint('$stack');
      _emit(IapPurchaseUiEvent.failed(IapCatalogConfig.paymentFailureMessage));
    } finally {
      _inFlightPurchaseKeys.remove(key);
    }
  }

  String _purchaseKey(PurchaseDetails purchase) {
    final id = purchase.purchaseID?.trim() ?? '';
    if (id.isNotEmpty) return '${purchase.productID}:$id';
    return '${purchase.productID}:${purchase.transactionDate}';
  }

  void _emit(IapPurchaseUiEvent event) {
    onUiEvent?.call(event);
  }
}

sealed class IapPurchaseUiEvent {
  const IapPurchaseUiEvent();

  factory IapPurchaseUiEvent.pending(String productId) = IapPurchasePending;

  factory IapPurchaseUiEvent.success({
    required String productId,
    required int coins,
    required int balance,
  }) = IapPurchaseSuccess;

  factory IapPurchaseUiEvent.failed(String message) = IapPurchaseFailed;

  factory IapPurchaseUiEvent.canceled() = IapPurchaseCanceled;
}

final class IapPurchasePending extends IapPurchaseUiEvent {
  const IapPurchasePending(this.productId);
  final String productId;
}

final class IapPurchaseSuccess extends IapPurchaseUiEvent {
  const IapPurchaseSuccess({
    required this.productId,
    required this.coins,
    required this.balance,
  });
  final String productId;
  final int coins;
  final int balance;
}

final class IapPurchaseFailed extends IapPurchaseUiEvent {
  const IapPurchaseFailed(this.message);
  final String message;
}

final class IapPurchaseCanceled extends IapPurchaseUiEvent {
  const IapPurchaseCanceled();
}
