// 朋友圈列表与详情共用卡片尺寸常量。
import 'package:flutter/material.dart';

/// 朋友圈列表与详情共用的卡片占位尺寸（与 [CircleFeedScreen] 列表一致）。
class CircleFeedLayout {
  CircleFeedLayout._();

  static const viewportFraction = 0.92;
  static const cardHorizontalPadding = 6.0;

  /// 列表页标题行：上 8 + 图 40 + 下 4
  static const _headerHeight = 52.0;

  /// Popular/Followed：上 28 + 下 24 + 胶囊 48
  static const _tabsHeight = 100.0;

  /// 底部分页指示：上 8 + 点 24 + 下 8（与列表有多页时对齐）
  static const _pagerHeight = 40.0;

  /// [AppBottomTabBar] 白色胶囊本体高度。
  static const bottomTabBarHeight = 68.0;

  /// 底栏在 [HomePage] 中占用的总高度（含上下 padding 与 Home Indicator）。
  static double homeBottomChromeHeight(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return 8 + bottomTabBarHeight + 6 + bottomInset;
  }

  static double cardWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width * viewportFraction;
  }

  /// 与 [CircleFeedScreen] → [CircleFeedPostPager] 内 `Expanded` 单卡同高。
  ///
  /// [reservePagerDots] 为 false 时与朋友圈仅 1 条帖子（无底部分页点）一致。
  static double cardHeight(
    BuildContext context, {
    bool reservePagerDots = true,
  }) {
    final media = MediaQuery.of(context);
    final pager = reservePagerDots ? _pagerHeight : 0.0;
    return media.size.height -
        media.padding.top -
        _headerHeight -
        _tabsHeight -
        pager -
        homeBottomChromeHeight(context);
  }

  /// 个人中心 My Post / My Like 纵向列表：无朋友圈标题与底部分页点，再略压低高度。
  static const profileVerticalListTrim = 56.0;

  /// 个人中心帖子卡片高度（比 [cardHeight] 更矮，避免纵向列表观感偏高）。
  static double profileVerticalPostCardHeight(BuildContext context) {
    return cardHeight(context, reservePagerDots: false) -
        profileVerticalListTrim;
  }

  static Size cardSize(BuildContext context) {
    return Size(cardWidth(context), cardHeight(context));
  }
}
