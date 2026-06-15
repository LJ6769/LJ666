// 个人中心 My Post / My Like 胶囊切换。
import 'package:flutter/material.dart';
import 'package:hilmi/widgets/profile/profile_assets.dart';

/// My Post / My Like 胶囊切换（与 [CircleFilterTabs] 同布局，勿拉伸切图）。
class ProfileFilterTabs extends StatelessWidget {
  const ProfileFilterTabs({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// My Post / My Like 切图显示高度（原 40，等比放大）。
  static const _tabHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final postActive = selectedIndex == 0;
    final likeActive = selectedIndex == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _TabChip(
            onTap: () => onSelected(0),
            asset: postActive
                ? ProfileAssets.tabMyPostActive
                : ProfileAssets.tabMyPostInactive,
          ),
          const SizedBox(width: 10),
          _TabChip(
            onTap: () => onSelected(1),
            asset: likeActive
                ? ProfileAssets.tabMyLikeActive
                : ProfileAssets.tabMyLikeInactive,
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.onTap,
    required this.asset,
  });

  final VoidCallback onTap;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        height: ProfileFilterTabs._tabHeight,
        fit: BoxFit.contain,
      ),
    );
  }
}
