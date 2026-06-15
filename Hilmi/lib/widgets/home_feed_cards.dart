// 首页 Live 卡与 Tipsy Bar 卡及尺寸计算常量。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../models/direct_chat_peer.dart';
import '../models/home_models.dart';
import '../utils/open_direct_chat.dart';
import '../utils/open_live_about_sheet.dart';
import '../utils/open_live_room.dart';
import '../utils/open_login_screen.dart';
import '../utils/open_star_profile.dart';
import 'circle/circle_assets.dart';
import 'common/cached_media_image.dart';
import 'follow/follow_action_button.dart';
import 'host_info_bar.dart';
import 'home_widgets.dart';

/// 头像条 / 操作按钮下移：一半在封面内、一半在标题区（相对封面底边）。
const double _liveOverlayHalfBleed = 20;

const double _liveHostRowHeight = 40.0;
const double _liveHostToTitleGap = 8.0;
const double _liveTitlePaddingLeft = 20.0;
const double _liveTitlePaddingRight = 10.0;
const double _liveTitlePaddingBottom = 10.0;
const double _liveHostRowPaddingLeft = 20.0;
const double _liveHostRowPaddingRight = 24.0;

/// Live 卡背景切图（圆角米白底 + 黑框）。
const String _liveCardBgAsset = 'assets/home/card_wide.png';

/// 横向卡片占屏宽比例（越大越宽）。
const double _liveCardWidthFraction = 0.88;

/// 封面宽高比（越大封面越矮）。
const double _liveCoverAspectRatio = 337 / 205;

/// 主播条 + 标题区占用高度（含内边距，不含与封面的重叠部分）。
double _liveCardBottomSectionHeight() {
  const titleLineHeight = 15.0 * 1.3 * 2;
  return _liveHostRowHeight +
      _liveHostToTitleGap +
      titleLineHeight +
      _liveTitlePaddingBottom;
}

/// 抵消字体度量 / 设备像素取整误差。
const double _liveCardLayoutSlack = 6;

/// 指定卡片宽度时的 Live 卡总高度。
double liveCardHeightForCardWidth(double cardWidth) {
  final coverHeight = cardWidth / _liveCoverAspectRatio;
  return coverHeight -
      _liveOverlayHalfBleed +
      _liveCardBottomSectionHeight() +
      2 * homeBorderWidth +
      _liveCardLayoutSlack;
}

/// 首页横向列表高度 = [liveCardHeightForScreenWidth]。
double liveCardHeightForScreenWidth(double screenWidth) {
  return liveCardHeightForCardWidth(screenWidth * _liveCardWidthFraction);
}

Future<void> openLiveHostChat(BuildContext context, LiveRoom room) async {
  final hostId = room.hostId?.trim() ?? '';
  if (hostId.isEmpty) return;

  if (!AuthService.isLoggedIn) {
    await openLoginScreen(context);
    return;
  }

  final name = room.hostName?.trim();
  await openDirectChat(
    context,
    peer: DirectChatPeer(
      id: hostId,
      name: name != null && name.isNotEmpty ? name : 'User',
      email: room.hostEmail,
      avatarUrl: room.hostAvatarUrl,
    ),
  );
}

class HomeLiveRoomCard extends StatelessWidget {
  const HomeLiveRoomCard({
    super.key,
    required this.room,
    this.fullWidth = false,
    this.onChatTap,
    this.onMoreTap,
  });

  final LiveRoom room;

  /// 列表页全宽卡片（左右各 20 边距由外层控制）。
  final bool fullWidth;
  final VoidCallback? onChatTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = fullWidth
        ? screenWidth - 40
        : screenWidth * _liveCardWidthFraction;
    final coverHeight = cardWidth / _liveCoverAspectRatio;
    final cardHeight = liveCardHeightForCardWidth(cardWidth);

    return Padding(
      padding: fullWidth
          ? EdgeInsets.zero
          : const EdgeInsets.only(right: 16),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(homeCardRadius),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => openLiveRoom(context, room),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          _liveCardBgAsset,
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: coverHeight,
                        child: HomeCardImageFrame(
                          padding: const EdgeInsets.fromLTRB(
                            homeCardMediaInset,
                            homeCardMediaInset,
                            homeCardMediaInset,
                            0,
                          ),
                          borderRadius: homeCardMediaBorderRadius,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              HomeImagePlaceholder(
                                imageUrl: room.coverUrl,
                                icon: Icons.videocam_outlined,
                              ),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Image.asset(
                                  'assets/home/live_badge.png',
                                  height: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: _liveTitlePaddingLeft,
                        bottom: _liveTitlePaddingBottom,
                        width: cardWidth -
                            _liveTitlePaddingLeft -
                            _liveTitlePaddingRight -
                            2 * homeBorderWidth,
                        child: Text(
                          room.title ?? 'Live stream title placeholder...',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: _liveHostRowPaddingLeft,
                right: _liveHostRowPaddingRight,
                top: coverHeight - _liveOverlayHalfBleed,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    HostInfoBar(
                      width: HostInfoBar.compactWidth,
                      avatarUrl: room.hostAvatarUrl,
                      name: room.hostName ?? 'Host Name',
                      email: room.hostEmail,
                      userId: room.hostId,
                      fallbackHandle: room.hostHandle,
                      onAvatarTap: room.hostId == null ||
                              room.hostId!.trim().isEmpty
                          ? null
                          : () => openStarProfileForUser(
                                context,
                                userId: room.hostId!,
                                name: room.hostName,
                                email: room.hostEmail,
                                imageUrl: room.hostAvatarUrl,
                              ),
                      trailing: FollowActionButton(
                        userId: room.hostId,
                        addAsset: 'assets/home/btn_add.png',
                      ),
                    ),
                    const Spacer(),
                    _LiveCardIconButton(
                      asset: 'assets/home/btn_chat.png',
                      onTap: onChatTap ??
                          () => openLiveHostChat(context, room),
                    ),
                    const SizedBox(width: 8),
                    _LiveCardIconButton(
                      asset: 'assets/home/btn_menu.png',
                      onTap: onMoreTap ??
                          () => openLiveAboutSheet(context, room),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveCardIconButton extends StatelessWidget {
  const _LiveCardIconButton({
    required this.asset,
    this.onTap,
  });

  final String asset;
  final VoidCallback? onTap;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Image.asset(
          asset,
          width: _size,
          height: _size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Tipsy Bar 卡背景切图（圆角米白底 + 黑框）。
const String _tipsyCardBgAsset = 'assets/home/card_tipsy.png';

/// Tipsy Bar 卡片高度（不含照片上下溢出部分）。
const double tipsyBarCardHeight = 146;

class HomeTipsyBarCard extends StatelessWidget {
  const HomeTipsyBarCard({
    super.key,
    required this.room,
    this.isFirst = true,
    this.isLast = true,
    /// 按列表序号强制左/右图；不传则用 [TipsyBarRoom.imageOnRight]。
    this.photoOnRight,
    this.onJoinTap,
    this.onMoreTap,
  });

  final TipsyBarRoom room;
  final bool isFirst;
  final bool isLast;
  final bool? photoOnRight;
  final VoidCallback? onJoinTap;
  final VoidCallback? onMoreTap;

  /// 相邻卡片之间的纵向间距（非首张/末张时缩小上下 padding）。
  static const _betweenCardsGap = 6.0;

  /// Tipsy Bar 封面图尺寸（列表卡片与创建页 Cover 共用）。
  static const coverPhotoWidth = 112.0;
  static const coverPhotoHeight = 155.0;
  static const coverPhotoRadius = 16.0;

  static const _photoWidth = coverPhotoWidth;
  static const _photoHeight = coverPhotoHeight;
  static const _photoRadius = coverPhotoRadius;
  static const _tiltRadians = 0.11;
  static const _photoMarginFromCardEdge = 10.0;

  /// 相对垂直居中再下移一点。
  static const _photoTopOffset = 8.0;

  /// 照片贴近卡片外侧（图在左/右均适用，第 1、2 张原样，第 3、4 张对齐）。
  static const _photoEdgeShift = -8.0;

  /// Join in 行高 44，一半在卡片底边内、一半在外。
  static const _joinRowBottomOverflow = 22.0;
  static const _joinRowHeight = 44.0;

  /// Stack 需包含 Join in 下半段，否则溢出区无法响应点击。
  static const _cardStackHeight =
      tipsyBarCardHeight + _joinRowBottomOverflow;
  static const _joinRowRightBase = 10.0;

  /// 图在右时 right 加大，把按钮往左挪、避开倾斜照片。
  static const _joinRowRightWhenPhotoOnRight = 120.0;

  double _joinRowRightInset(bool photoOnRight) {
    if (!photoOnRight) return _joinRowRightBase;
    return _joinRowRightWhenPhotoOnRight;
  }

  static double _rotatedHorizontalExtent(double width, double height, double angle) {
    return width * math.cos(angle).abs() + height * math.sin(angle).abs();
  }

  static double _rotatedVerticalExtent(double width, double height, double angle) {
    return width * math.sin(angle).abs() + height * math.cos(angle).abs();
  }

  /// 文字与照片之间的横向间距。
  static const _textPhotoGap = 2.0;

  double get _photoSideInset => _photoMarginFromCardEdge + _photoEdgeShift;

  double _textInsetOnPhotoSide(bool photoOnRight) {
    return _photoSideInset +
        _rotatedHorizontalExtent(_photoWidth, _photoHeight, _tiltRadians) +
        _textPhotoGap;
  }

  /// 照片上下溢出卡片的高度（用于外层 padding，避免被裁切）。
  static double get tipsyPhotoVerticalBleed {
    final overflow =
        _rotatedVerticalExtent(_photoWidth, _photoHeight, _tiltRadians) -
            tipsyBarCardHeight;
    return math.max(0, overflow / 2) + 8;
  }

  @override
  Widget build(BuildContext context) {
    final onRight = photoOnRight ?? room.imageOnRight;
    final textInset = _textInsetOnPhotoSide(onRight);
    final verticalBleed = tipsyPhotoVerticalBleed;
    final topPadding = isFirst ? verticalBleed : _betweenCardsGap;
    final bottomPadding =
        isLast ? verticalBleed + 4 : _betweenCardsGap;
    final photoTop =
        (tipsyBarCardHeight -
                _rotatedVerticalExtent(_photoWidth, _photoHeight, _tiltRadians)) /
                2 +
            _photoTopOffset;

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: bottomPadding,
      ),
      child: SizedBox(
        height: _cardStackHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: tipsyBarCardHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(homeCardRadius),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        _tipsyCardBgAsset,
                        fit: BoxFit.fill,
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          onRight ? 14 : textInset,
                          12,
                          onRight ? textInset : 14,
                          44,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.title ?? 'Room title placeholder',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              room.description ??
                                  'Description placeholder text...',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF616161),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: onRight ? 14 : textInset,
                      right: onRight ? textInset : null,
                      bottom: 15,
                      child: _ParticipantAvatars(
                        urls: room.participantAvatarUrls,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: onRight ? null : _photoSideInset,
              right: onRight ? _photoSideInset : null,
              top: photoTop,
              child: Transform.rotate(
                angle: onRight ? _tiltRadians : -_tiltRadians,
                child: _TipsyOverflowPhoto(
                  imageUrl: room.coverUrl,
                  width: _photoWidth,
                  height: _photoHeight,
                  radius: _photoRadius,
                ),
              ),
            ),
            Positioned(
              right: _joinRowRightInset(onRight),
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onJoinTap,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: _joinRowHeight,
                      child: Image.asset(
                        'assets/home/join_in.png',
                        height: _joinRowHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onMoreTap,
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      'assets/home/btn_menu.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 倾斜溢出卡片的照片：仅黑边圆角，无额外白底框。
class _TipsyOverflowPhoto extends StatelessWidget {
  const _TipsyOverflowPhoto({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black, width: homeBorderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - homeBorderWidth),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            HomeImagePlaceholder(
              imageUrl: imageUrl,
              icon: Icons.local_bar_outlined,
              borderRadius: radius - homeBorderWidth,
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Image.asset(
                'assets/home/chat_badge.png',
                height: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantAvatars extends StatelessWidget {
  const _ParticipantAvatars({required this.urls});

  final List<String?> urls;

  static const _avatarSize = 28.0;

  /// 越小叠得越紧（中心距 = step，可见宽度 ≈ size - step）。
  static const _overlapStep = 14.0;

  @override
  Widget build(BuildContext context) {
    final count = urls.isEmpty ? 4 : urls.length.clamp(1, 5);
    final width = _avatarSize + (count - 1) * _overlapStep;

    // Stack 后绘制的在上层：自左向右绘制，右侧 (i 大) 最后画、压在上层。
    final stackChildren = <Widget>[];
    for (var i = 0; i < count; i++) {
      stackChildren.add(
        Positioned(
          left: i * _overlapStep,
          child: _ParticipantAvatarCircle(
            url: i < urls.length ? urls[i] : null,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: _avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: stackChildren,
      ),
    );
  }
}

class _ParticipantAvatarCircle extends StatelessWidget {
  const _ParticipantAvatarCircle({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';

    return Container(
      width: _ParticipantAvatars._avatarSize,
      height: _ParticipantAvatars._avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: const Color(0xFFE8E4DC),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedMediaImage(
                url: imageUrl,
                fit: BoxFit.cover,
                width: _ParticipantAvatars._avatarSize,
                height: _ParticipantAvatars._avatarSize,
              )
            : const Icon(
                Icons.person,
                size: 14,
                color: Color(0xFFB8B2A8),
              ),
      ),
    );
  }
}

/// 首页 Live / Tipsy 无数据时居中鸡尾酒图标（与朋友圈空态一致）。
class HomeFeedEmptyPlaceholder extends StatelessWidget {
  const HomeFeedEmptyPlaceholder({super.key});

  static const _iconSize = 72.0;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      CircleAssets.icEmptyFeed,
      width: _iconSize,
      height: _iconSize,
      fit: BoxFit.contain,
    );
  }
}
