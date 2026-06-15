// Tipsy Bar 列表顶部「创建房间」横幅。
import 'package:flutter/material.dart';
import 'package:hilmi/widgets/tipsy/tipsy_assets.dart';

/// Tipsy Bar 顶部「创建」入口横幅。
class TipsyCreateBanner extends StatelessWidget {
  const TipsyCreateBanner({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        TipsyAssets.voiceBanner,
        fit: BoxFit.fitWidth,
      ),
    );
  }
}
