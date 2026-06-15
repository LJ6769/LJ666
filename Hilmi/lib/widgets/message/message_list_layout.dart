import 'package:hilmi/widgets/home_widgets.dart';

/// 消息列表页布局常量（对齐设计稿 @3x）。
abstract final class MessageListLayout {
  static const designWidth = 375.0;

  static const borderWidth = 3.0;
  static const cardRadius = 22.0;

  /// 与首页 [HomeProfileStoriesRow] 明星卡一致（108×148 @ [homeProfileStoryCardScale]）。
  static const featuredCardW =
      HomeProfileDiscoverCard.cardWidth * homeProfileStoryCardScale;
  static const featuredCardH =
      HomeProfileDiscoverCard.cardHeight * homeProfileStoryCardScale;
  static const featuredRowH = featuredCardH;

  static const allChatH = 40.0;

  static const conversationAvatar = 48.0;
  static const conversationRowPadV = 8.0;

  /// chat_row_bg.png 切图尺寸（@3x：1005×201px）。
  static const chatRowBgWidthPx = 1005.0;
  static const chatRowBgHeightPx = 201.0;

  static double chatRowHeightForWidth(double width) =>
      width * chatRowBgHeightPx / chatRowBgWidthPx;

  /// 左滑露出宽度 = [deleteButtonW] + [deleteRevealGap]。
  static const deleteButtonW = 50.0;
  static const deleteButtonH = 66.0;

  /// 垃圾桶相对垂直居中的上移量。
  static const deleteButtonUpOffset = 6.0;

  /// 卡片与垃圾桶之间的横向间距。
  static const deleteRevealGap = 4.0;

  /// 空列表马天尼图标逻辑高度（@3x 165px → 55pt，略放大便于识别）。
  static const emptyIconSize = 72.0;
}
