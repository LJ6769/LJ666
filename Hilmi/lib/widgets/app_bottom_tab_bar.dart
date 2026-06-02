import 'package:flutter/material.dart';

/// 应用底部四栏导航（首页 / Circle / 消息 / 我的）。
class AppBottomTabBar extends StatelessWidget {
  const AppBottomTabBar({
    super.key,
    required this.selectedIndex,
    required this.tabAssets,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<String> tabAssets;
  final ValueChanged<int> onSelected;

  static const _inactiveMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.45, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 6 + bottomInset),
      child: Container(
        height: 68,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.black, width: 3),
        ),
        child: Row(
          children: List.generate(tabAssets.length, (index) {
            final isSelected = index == selectedIndex;
            Widget icon = Image.asset(
              tabAssets[index],
              width: 112,
              height: 70,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            );

            if (!isSelected) {
              icon = ColorFiltered(
                colorFilter: const ColorFilter.matrix(_inactiveMatrix),
                child: icon,
              );
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 70,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: icon,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
