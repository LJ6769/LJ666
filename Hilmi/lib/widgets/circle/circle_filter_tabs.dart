import 'package:flutter/material.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';

/// Popular / Followed 胶囊切换（四态切图，选中/未选中均用设计稿资源）。
class CircleFilterTabs extends StatelessWidget {
  const CircleFilterTabs({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final popularActive = selectedIndex == 0;
    final followedActive = selectedIndex == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _TabChip(
            onTap: () => onSelected(0),
            asset: popularActive
                ? CircleAssets.tabPopularActive
                : CircleAssets.tabPopularInactive,
          ),
          const SizedBox(width: 10),
          _TabChip(
            onTap: () => onSelected(1),
            asset: followedActive
                ? CircleAssets.tabFollowedActive
                : CircleAssets.tabFollowedInactive,
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
        height: CircleFilterTabs._tabHeight,
        fit: BoxFit.contain,
      ),
    );
  }
}
