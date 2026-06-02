import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/core/profile_refresh_signal.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/models/circle_comment.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/utils/open_circle_post.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/circle/circle_post_card.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';
/// 详情页：上方帖子区与下方评论区 6:3。
const _detailPostAreaFlex = 6;
const _detailCommentsAreaFlex = 3;

/// 详情页黑线以上背景。
const _detailPostBackground = Color(0xFFFEEFEF);

/// 详情帖文介绍：超过此行数在固定高度内滚动，不挤压视频区。
const _detailCaptionFontSize = 14.0;
const _detailCaptionLineHeight = 1.45;
const _detailCaptionMaxLines = 3;

double get _detailCaptionBodyHeight =>
    _detailCaptionFontSize * _detailCaptionLineHeight * _detailCaptionMaxLines;

/// 评论区背景（略深于页面底色的米色）。
const _detailCommentsBackground = Color(0xFFFDF9ED);

/// 朋友圈帖子详情（对齐设计稿：帖子 + 时间 + 评论 + 底部输入）。
class CirclePostDetailScreen extends StatefulWidget {
  const CirclePostDetailScreen({
    super.key,
    required this.post,
    required this.initialFollowed,
    required this.initialLiked,
    this.repository = const CircleRepository(),
  });

  final CirclePost post;
  final bool initialFollowed;
  final bool initialLiked;
  final CircleRepository repository;

  @override
  State<CirclePostDetailScreen> createState() => _CirclePostDetailScreenState();
}

class _CirclePostDetailScreenState extends State<CirclePostDetailScreen> {
  late bool _isFollowed;
  late bool _isLiked;
  List<CircleComment> _comments = [];
  bool _loadingComments = true;
  bool _sendingComment = false;
  final _commentController = TextEditingController();
  final _commentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isFollowed = widget.initialFollowed;
    _isLiked = widget.initialLiked;
    _loadComments();
    _prefetchVideoSignature();
  }

  void _prefetchVideoSignature() {
    for (final item in widget.post.media) {
      if (item.isVideo && item.videoPath != null && item.videoPath!.isNotEmpty) {
        widget.repository.prefetchVideoSignature(item.videoPath);
        break;
      }
    }
  }

  @override
  void dispose() {
    _commentScrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _scrollCommentsToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_commentScrollController.hasClients) return;
      final pos = _commentScrollController.position;
      final target = pos.maxScrollExtent;
      if (animated) {
        _commentScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _commentScrollController.jumpTo(target);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_commentScrollController.hasClients) return;
        final p = _commentScrollController.position;
        if (p.pixels < p.maxScrollExtent - 2) {
          _commentScrollController.jumpTo(p.maxScrollExtent);
        }
      });
    });
  }

  Future<void> _loadComments() async {
    final comments = await widget.repository.fetchComments(widget.post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments
          .where((c) => !BlockService.isBlocked(c.authorId))
          .toList();
      _loadingComments = false;
    });
    if (_comments.isNotEmpty) {
      _scrollCommentsToEnd(animated: false);
    }
  }

  void _popWithResult({bool deleted = false}) {
    Navigator.of(context).pop(
      CirclePostDetailResult(
        isFollowed: _isFollowed,
        isLiked: _isLiked,
        deleted: deleted,
      ),
    );
  }

  Future<void> _onFollowTap() async {
    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to follow')) {
      return;
    }
    if (!mounted) return;
    try {
      final following = await FollowService.toggle(widget.post.authorId);
      if (!mounted) return;
      setState(() => _isFollowed = following);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onLikeTap() async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      if (!mounted || !AuthService.isLoggedIn) return;
      setState(() => _isLiked = LikeService.isLiked(widget.post.id));
      return;
    }
    try {
      final liked = await LikeService.toggle(widget.post.id);
      if (!mounted) return;
      setState(() => _isLiked = liked);
      ProfileRefreshSignal.notify();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onMoreTap() async {
    final result = await CirclePostMoreSheet.show(
      context,
      post: widget.post,
      repository: widget.repository,
    );
    if (!mounted || result == null) return;
    if (result == CirclePostMoreResult.deleted) {
      _popWithResult(deleted: true);
      return;
    }
    if (result == CirclePostMoreResult.blacklisted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onSendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sendingComment) return;

    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to comment')) {
      return;
    }
    if (!mounted) return;

    setState(() => _sendingComment = true);
    try {
      final comment = await widget.repository.sendComment(
        postId: widget.post.id,
        content: text,
      );
      if (!mounted) return;
      _commentController.clear();
      dismissKeyboard(context);
      setState(() {
        _sendingComment = false;
        if (!BlockService.isBlocked(comment.authorId)) {
          _comments = [..._comments, comment];
        }
      });
      _scrollCommentsToEnd();
    } catch (error) {
      debugPrint('[CirclePostDetailScreen] send comment: $error');
      if (!mounted) return;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send comment: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithResult();
      },
      child: Scaffold(
        backgroundColor: _detailCommentsBackground,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: _detailPostAreaFlex,
              child: ColoredBox(
                color: _detailPostBackground,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DetailTopBar(onBack: _popWithResult),
                      Expanded(
                        child: _PostSection(
                          post: widget.post,
                          isFollowed: _isFollowed,
                          isLiked: _isLiked,
                          onFollowTap: _onFollowTap,
                          onLikeTap: _onLikeTap,
                          onMoreTap: _onMoreTap,
                          resolveVideoUrl: widget.repository.resolveVideoUrl,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: 1.5,
              color: Colors.black,
            ),
            Expanded(
              flex: _detailCommentsAreaFlex,
              child: _CommentsPanel(
                loading: _loadingComments,
                comments: _comments,
                scrollController: _commentScrollController,
                commentController: _commentController,
                sending: _sendingComment,
                onSend: _onSendComment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostSection extends StatelessWidget {
  const _PostSection({
    required this.post,
    required this.isFollowed,
    required this.isLiked,
    required this.onFollowTap,
    required this.onLikeTap,
    required this.onMoreTap,
    required this.resolveVideoUrl,
  });

  final CirclePost post;
  final bool isFollowed;
  final bool isLiked;
  final VoidCallback onFollowTap;
  final VoidCallback onLikeTap;
  final VoidCallback onMoreTap;
  final Future<String?> Function(String? videoPath) resolveVideoUrl;

  @override
  Widget build(BuildContext context) {
    final hasText = post.content.isNotEmpty || post.createdAt != null;
    const bodyStyle = TextStyle(
      fontSize: _detailCaptionFontSize,
      height: _detailCaptionLineHeight,
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CirclePostCard(
              post: post,
              hideFollow: post.authorId == AuthService.cachedProfile?.id,
              isFollowed: isFollowed,
              isLiked: isLiked,
              onFollowTap: onFollowTap,
              onLikeTap: onLikeTap,
              onMoreTap: onMoreTap,
              fillHeight: true,
              flushMediaToFrame: true,
              enableMediaSwipe: true,
              edgeToEdge: true,
              captionMaxLines: 0,
              playbackEnabled: true,
              resolveVideoUrl: resolveVideoUrl,
            ),
          ),
          if (hasText)
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (post.content.isNotEmpty)
                    SizedBox(
                      height: _detailCaptionBodyHeight,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: Text(
                          post.content,
                          style: bodyStyle,
                        ),
                      ),
                    ),
                  if (post.createdAt != null) ...[
                    if (post.content.isNotEmpty) const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(post.createdAt!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
}

class _CommentsPanel extends StatelessWidget {
  const _CommentsPanel({
    required this.loading,
    required this.comments,
    required this.scrollController,
    required this.commentController,
    required this.sending,
    required this.onSend,
  });

  final bool loading;
  final List<CircleComment> comments;
  final ScrollController scrollController;
  final TextEditingController commentController;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _detailCommentsBackground,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      CircleAssets.titleComments,
                      height: 28,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _CommentsSection(
                        loading: loading,
                        comments: comments,
                        scrollController: scrollController,
                      ),
                    ),
                    _CommentInputBar(
                      controller: commentController,
                      sending: sending,
                      onSend: onSend,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                CircleAssets.btnDetailBack,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.loading,
    required this.comments,
    required this.scrollController,
  });

  final bool loading;
  final List<CircleComment> comments;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Color(0xFFD14D4D),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (comments.isEmpty) {
      return Center(
        child: Image.asset(
          CircleAssets.icEmptyFeed,
          width: 72,
          height: 72,
          fit: BoxFit.contain,
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.zero,
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _CommentTile(comment: comments[index]),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CircleComment comment;

  @override
  Widget build(BuildContext context) {
    final name = comment.authorName.trim().isNotEmpty
        ? comment.authorName.trim()
        : 'Guest';

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, height: 1.45),
        children: [
          TextSpan(
            text: '$name:',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          TextSpan(
            text: comment.content,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  const _CommentInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              CircleAssets.detailCommentInputBg,
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onTapOutside: (_) => dismissKeyboard(context),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Please enter...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                GestureDetector(
                  onTap: sending ? null : onSend,
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: sending ? 0.45 : 1,
                    child: Image.asset(
                      CircleAssets.btnCommentSend,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
