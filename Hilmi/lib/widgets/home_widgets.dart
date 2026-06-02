import 'package:flutter/material.dart';

import '../models/home_models.dart';
import 'package:hilmi/widgets/coin_balance_bar.dart';

import 'common/cached_media_image.dart';

const Color homeAccentRed = Color(0xFFC84B4B);
const double homeCardRadius = 22;
const double homeBorderWidth = 3;

/// 卡片内图片与黑色边框的间距（对齐 Tjgo `_frameInset` 9pt）。
const double homeCardMediaInset = 9;

/// 图片圆角：与黑框同心（外圆角 − 边框 − 内边距），与背景框弧线一致。
double get homeCardMediaRadius =>
    (homeCardRadius - homeBorderWidth - homeCardMediaInset)
        .clamp(0.0, homeCardRadius);

BorderRadius get homeCardMediaBorderRadius =>
    BorderRadius.circular(homeCardMediaRadius);

/// 给卡片内图片加内边距并圆角裁剪，避免顶到黑边。
class HomeCardImageFrame extends StatelessWidget {
  const HomeCardImageFrame({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(homeCardMediaInset),
      child: ClipRRect(
        borderRadius: borderRadius ?? homeCardMediaBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class HomeBorderedCard extends StatelessWidget {
  const HomeBorderedCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: Colors.black, width: homeBorderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}

/// 图片占位，[imageUrl] 有值时显示网络图（圆角与 [homeCardMediaRadius] 一致）。
class HomeImagePlaceholder extends StatelessWidget {
  const HomeImagePlaceholder({
    super.key,
    this.imageUrl,
    this.aspectRatio,
    this.borderRadius,
    this.icon,
  });

  final String? imageUrl;
  final double? aspectRatio;

  /// 默认与背景框同心圆角；可传 [homeCardMediaRadius] 或单独指定。
  final double? borderRadius;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? homeCardMediaRadius;
    final rounded = BorderRadius.circular(radius);

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = CachedMediaImage(
        url: imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            _placeholderBody(radius: radius),
      );
    } else {
      content = _placeholderBody(radius: radius);
    }

    content = ClipRRect(
      borderRadius: rounded,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio!, child: content);
    }
    return content;
  }

  Widget _placeholderBody({required double radius}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFE8E4DC),
      alignment: Alignment.center,
      child: Icon(
        icon ?? Icons.image_outlined,
        size: 32,
        color: const Color(0xFFB8B2A8),
      ),
    );
  }
}

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.iconAsset,
    this.onSeeAll,
  });

  /// 分区标题图（已含标题文字），后续可换为数据库配置的 asset/url。
  final String iconAsset;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                iconAsset,
                height: 32,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'See All',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9E9E),
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF9E9E9E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeDiscoverHeader extends StatelessWidget {
  const HomeDiscoverHeader({super.key, required this.coinBalance});

  final int coinBalance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/home/discover_title.png',
            height: 44,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          CoinBalanceBar(
            coinBalance: coinBalance,
            borderWidth: homeBorderWidth,
          ),
        ],
      ),
    );
  }
}

class HomeProfileStoriesRow extends StatelessWidget {
  const HomeProfileStoriesRow({
    super.key,
    required this.stories,
    this.onProfileTap,
    this.onChatTap,
  });

  final List<ProfileStory> stories;
  final void Function(ProfileStory story)? onProfileTap;
  final void Function(ProfileStory story)? onChatTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: stories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];
          return HomeProfileDiscoverCard(
            imageUrl: story.imageUrl,
            onProfileTap:
                onProfileTap == null ? null : () => onProfileTap!(story),
            onChatTap:
                onChatTap == null ? null : () => onChatTap!(story),
          );
        },
      ),
    );
  }
}

/// Discover / Message 横滑明星大卡（108×148、黑框、右下角聊天角标）。
class HomeProfileDiscoverCard extends StatelessWidget {
  const HomeProfileDiscoverCard({
    super.key,
    this.imageUrl,
    this.onProfileTap,
    this.onChatTap,
  });

  final String? imageUrl;
  final VoidCallback? onProfileTap;
  final VoidCallback? onChatTap;

  static const cardWidth = 108.0;
  static const cardHeight = 148.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: HomeBorderedCard(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onProfileTap,
              behavior: HitTestBehavior.opaque,
              child: HomeImagePlaceholder(
                imageUrl: imageUrl,
                borderRadius: homeCardRadius - homeBorderWidth,
                icon: Icons.person_outline,
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: onChatTap,
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  'assets/home/btn_chat.png',
                  width: 36,
                  height: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
