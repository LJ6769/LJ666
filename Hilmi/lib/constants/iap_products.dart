// 内购商品兼容旧名，请改用 IapCatalogConfig。
export 'package:hilmi/config/iap_catalog_config.dart';

import 'package:hilmi/config/iap_catalog_config.dart' show IapCatalogConfig;

/// 兼容旧名；请使用 [IapCatalogConfig]。
@Deprecated('Use IapCatalogConfig from package:hilmi/config/iap_catalog_config.dart')
typedef IapProducts = IapCatalogConfig;
