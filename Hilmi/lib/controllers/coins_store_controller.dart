// 金币商城页：IAP 初始化与购买状态。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/services/iap_purchase_service.dart';

class CoinsStoreController extends GetxController {
  static const designWidth = 375.0;
  static const gridHPadding = 20.0;
  static const gridSpacing = 10.0;
  static const cellAspectRatio = 0.84;

  final _iap = IapPurchaseService.instance;
  final purchasingProductId = RxnString();
  final iapReady = false.obs;

  double scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  int get coins => AuthService.cachedProfile?.coins ?? 0;

  bool get isQuerying => _iap.isQuerying;

  @override
  void onInit() {
    super.onInit();
    _iap.onUiEvent = _onIapUiEvent;
    unawaited(_initIap());
  }

  @override
  void onClose() {
    if (_iap.onUiEvent == _onIapUiEvent) {
      _iap.onUiEvent = null;
    }
    super.onClose();
  }

  String displayPrice(String productId, String fallbackPrice) =>
      _iap.displayPrice(productId, fallbackPrice);

  Future<void> _initIap() async {
    await _iap.initialize();
    if (isClosed) return;
    iapReady.value = _iap.isAvailable;
  }

  void _onIapUiEvent(IapPurchaseUiEvent event) {
    final context = Get.context;
    if (context == null || !context.mounted) return;
    switch (event) {
      case IapPurchasePending(:final productId):
        purchasingProductId.value = productId;
      case IapPurchaseSuccess(:final coins):
        purchasingProductId.value = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$coins coins added successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case IapPurchaseFailed(:final message):
        purchasingProductId.value = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case IapPurchaseCanceled():
        purchasingProductId.value = null;
    }
  }

  Future<void> onPurchaseTap(BuildContext context, IapProductCatalogEntry entry) async {
    if (purchasingProductId.value != null) return;

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
    if (!started &&
        context.mounted &&
        purchasingProductId.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(IapCatalogConfig.paymentFailureMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
