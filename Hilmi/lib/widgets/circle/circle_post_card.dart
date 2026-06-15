// 朋友圈单条帖子卡片（媒体 + 作者条 + 操作）。
import 'package:flutter/material.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/circle/circle_post_video_preview.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/home_widgets.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/host_info_bar.dart';

/// 朋友圈单条帖子卡片（大图 + 作者条 + 文案）。
class CirclePostCard extends StatefulWidget {
  const CirclePostCard({
    super.key,
    required this.post,
    required this.isFollowed,
    required this.isLiked,
    required this.onFollowTap,
    required this.onLikeTap,
    required this.onMoreTap,
    this.hideFollow = false,
    this.fillHeight = false,
    this.captionMaxLines = 2,
    this.edgeToEdge = false,
    this.playbackEnabled = false,
    this.resolveVideoUrl,
    this.createdAt,
    this.flushMediaToFrame = false,
    this.enableMediaSwipe = false,
  });

  final CirclePost post;
  final bool isFollowed;
  final bool isLiked;
  final VoidCallback onFollowTap;
  final VoidCallback onLikeTap;
  final VoidCallback onMoreTap;

  /// 个人中心自己的帖子：不展示关注按钮。
  final bool hideFollow;

  /// 横向翻页信息流：占满可用高度，媒体区尽量放大。
  final bool fillHeight;

  /// 文案最大行数；为 null 时不限制（详情页）。
  final int? captionMaxLines;

  /// 为 true 时不加列表页左右 20 外边距（详情页用）。
  final bool edgeToEdge;

  /// 详情页为 true：点击播放按钮后再加载视频。
  final bool playbackEnabled;
  final Future<String?> Function(String videoPath)? resolveVideoUrl;

  /// 详情页：文案下方展示时间。
  final DateTime? createdAt;

  /// 媒体铺满黑框内侧（去掉 9pt 内边距，详情页）。
  final bool flushMediaToFrame;

  /// 多图时允许在卡片内左右滑动（个人中心竖向列表、详情页）。
  final bool enableMediaSwipe;

  @override
  State<CirclePostCard> createState() => _CirclePostCardState();
}

class _CirclePostCardState extends State<CirclePostCard> {
  late final PageController _mediaPageController;
  int _mediaPageIndex = 0;

  /// 媒体区略矮，作者条一半叠在图上、一半在图外。
  static const _compactMediaAspectRatio = 343 / 185;
  static const _authorBarHeight = 38.0;
  static const _authorBarOverlap = _authorBarHeight / 2;
  static const _actionButtonSize = 42.0;

  BorderRadius get _mediaClipRadius => widget.flushMediaToFrame
      ? BorderRadius.circular(
          (homeCardRadius - homeBorderWidth).clamp(0.0, homeCardRadius),
        )
      : homeCardMediaBorderRadius;

  @override
  void initState() {
    super.initState();
    _mediaPageController = PageController();
    _mediaPageController.addListener(_onMediaPageChanged);
  }

  @override
  void dispose() {
    _mediaPageController.removeListener(_onMediaPageChanged);
    _mediaPageController.dispose();
    super.dispose();
  }

  void _onMediaPageChanged() {
    final page = _mediaPageController.page?.round() ?? 0;
    if (page != _mediaPageIndex && mounted) {
      setState(() => _mediaPageIndex = page);
    }
  }

  void _goToMediaPage(int index) {
    if (index == _mediaPageIndex) return;
    _mediaPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fillHeight) {
      final card = LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: _buildFramedCard(
              media: _buildMediaWithOverlays(),
              caption: _buildCaption(maxLines: widget.captionMaxLines),
            ),
          );
        },
      );
      if (widget.flushMediaToFrame) return card;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: card,
      );
    }

    return Padding(
      padding: widget.edgeToEdge
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: _buildFramedCard(
        media: _buildMediaWithOverlays(),
        caption: _buildCaption(maxLines: widget.captionMaxLines),
      ),
    );
  }

  Widget _buildFramedCard({
    required Widget media,
    required Widget caption,
  }) {
    const inset = homeCardMediaInset;
    const cardFill = Color(0xFFFDF9ED);
    final flush = widget.flushMediaToFrame;
    final halfBtn = _actionButtonSize / 2;

    final captionBlock = flush
        ? const SizedBox.shrink()
        : Transform.translate(
            offset: Offset(0, -halfBtn),
            child: IgnorePointer(child: caption),
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.fillHeight) Expanded(child: media) else media,
        captionBlock,
      ],
    );

    // 详情页：黑框只包视频，控件叠在底边并落在 #FEEFEF 上（与列表叠层一致）。
    if (flush) {
      return content;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(homeCardRadius),
        border: Border.all(color: Colors.black, width: homeBorderWidth),
      ),
      clipBehavior: Clip.none,
      child: Padding(
        padding: const EdgeInsets.all(inset),
        child: content,
      ),
    );
  }

  Widget _buildFlushVideoFrame({required Widget child, required double height}) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(homeCardRadius),
          border: Border.all(color: Colors.black, width: homeBorderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: _mediaClipRadius,
          child: child,
        ),
      ),
    );
  }

  Widget _buildCaption({required int? maxLines}) {
    final hasContent = widget.post.content.isNotEmpty;
    final hasTime = widget.createdAt != null;
    if (maxLines == 0 && !hasTime) {
      return const SizedBox.shrink();
    }
    if (!hasContent && !hasTime) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        top: hasContent ? 10 + _authorBarOverlap : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasContent)
            Text(
              widget.post.content,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          if (hasTime) ...[
            if (hasContent) const SizedBox(height: 8),
            Text(
              _formatTimestamp(widget.createdAt!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  /// 视频区黑框紧贴媒体；作者条 / 点赞叠在底边（各一半在内、一半在外）。
  Widget _buildMediaWithOverlays() {
    final media = widget.post.media;
    final lockInnerSwipe =
        widget.fillHeight && media.length > 1 && !widget.enableMediaSwipe;
    final halfBtn = _actionButtonSize / 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        final flush = widget.flushMediaToFrame;
        final double mediaH;
        if (widget.fillHeight && maxH.isFinite && maxH > halfBtn) {
          // 底栏半外露区：叠层控件用 bottom 正向定位，与列表一致。
          mediaH = maxH - halfBtn;
        } else if (maxW.isFinite && maxW > 0) {
          mediaH = maxW / _compactMediaAspectRatio;
        } else {
          mediaH = 185;
        }

        final stackH = widget.fillHeight ? maxH : mediaH + halfBtn;
        final overlayBottom = halfBtn - _authorBarOverlap;

        final mediaContent = _buildMediaContent(media, lockInnerSwipe);
        final videoLayer = flush
            ? _buildFlushVideoFrame(height: mediaH, child: mediaContent)
            : ClipRRect(
                borderRadius: _mediaClipRadius,
                child: SizedBox(height: mediaH, child: mediaContent),
              );

        return SizedBox(
          height: stackH.isFinite ? stackH : null,
          width: maxW.isFinite ? maxW : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: mediaH,
                child: videoLayer,
              ),
              if (media.length > 1 && widget.enableMediaSwipe)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: mediaH,
                  child: _buildMediaDots(media.length, false),
                ),
              Positioned(
                left: 8,
                right: 100,
                bottom: overlayBottom,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _AuthorBar(
                    post: widget.post,
                    isFollowed: widget.isFollowed,
                    onFollowTap: widget.onFollowTap,
                    hideFollow: widget.hideFollow,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      asset: widget.isLiked
                          ? CircleAssets.icHeartLiked
                          : CircleAssets.icHeart,
                      onTap: widget.onLikeTap,
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      asset: CircleAssets.icMore,
                      onTap: widget.onMoreTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaContent(List<CircleMedia> media, bool lockInnerSwipe) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (media.isEmpty)
          const ColoredBox(color: Color(0xFFE8E4DC))
        else if (media.length == 1 || !widget.enableMediaSwipe)
          _MediaTile(
            item: media.first,
            showFullMedia: widget.flushMediaToFrame,
            playbackEnabled: widget.playbackEnabled,
            resolveVideoUrl: widget.resolveVideoUrl,
          )
        else
          PageView.builder(
            controller: _mediaPageController,
            physics: lockInnerSwipe
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: media.length,
            itemBuilder: (context, index) {
              return _MediaTile(
                item: media[index],
                showFullMedia: widget.flushMediaToFrame,
                playbackEnabled: widget.playbackEnabled,
                resolveVideoUrl: widget.resolveVideoUrl,
              );
            },
          ),
      ],
    );
  }

  Widget _buildMediaDots(int count, bool tappable) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: _authorBarOverlap + 8),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final dot = Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _mediaPageIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
          );

          if (!tappable) return dot;

          return GestureDetector(
            onTap: () => _goToMediaPage(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: dot,
            ),
          );
        }),
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    this.showFullMedia = false,
    this.playbackEnabled = false,
    this.resolveVideoUrl,
  });

  final CircleMedia item;
  final bool showFullMedia;
  final bool playbackEnabled;
  final Future<String?> Function(String videoPath)? resolveVideoUrl;

  static const _letterboxLight = Color(0xFFE8E4DC);
  static const _letterboxDark = Color(0xFF2A2420);

  @override
  Widget build(BuildContext context) {
    final fit = showFullMedia ? BoxFit.contain : BoxFit.cover;
    final letterbox = showFullMedia ? _letterboxDark : _letterboxLight;

    if (item.isVideo) {
      return CirclePostVideoPreview(
        videoPath: item.videoPath,
        posterUrl: item.previewUrl,
        posterCacheKey: item.previewCacheKey,
        playbackEnabled: playbackEnabled,
        fit: showFullMedia || playbackEnabled ? BoxFit.contain : BoxFit.cover,
        resolveVideoUrl: resolveVideoUrl,
      );
    }

    final url = item.previewUrl;
    if (url.isEmpty) {
      return ColoredBox(color: letterbox);
    }
    return ColoredBox(
      color: letterbox,
      child: CachedMediaImage(
        url: url,
        cacheKey: item.previewCacheKey,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => ColoredBox(color: letterbox),
      ),
    );
  }
}

class _AuthorBar extends StatelessWidget {
  const _AuthorBar({
    required this.post,
    required this.isFollowed,
    required this.onFollowTap,
    this.hideFollow = false,
  });

  final CirclePost post;
  final bool isFollowed;
  final VoidCallback onFollowTap;
  final bool hideFollow;

  @override
  Widget build(BuildContext context) {
    return HostInfoBar(
      width: HostInfoBar.compactWidth,
      avatarUrl: post.authorAvatarUrl,
      avatarCacheKey: post.authorAvatarPath,
      name: post.authorName,
      email: post.authorEmail,
      userId: post.authorId,
      onAvatarTap: () => openStarProfileForUser(
        context,
        userId: post.authorId,
        name: post.authorName,
        email: post.authorEmail,
        imageUrl: post.authorAvatarUrl,
      ),
      trailing: hideFollow
          ? null
          : GestureDetector(
              onTap: onFollowTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                isFollowed
                    ? CircleAssets.btnFollowCheck
                    : CircleAssets.btnFollowAdd,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.asset,
    required this.onTap,
  });

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        width: 42,
        height: 42,
        fit: BoxFit.contain,
      ),
    );
  }
}
