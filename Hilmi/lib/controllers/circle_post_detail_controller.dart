// 朋友圈帖子详情：帖文区 + 评论区状态。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/core/profile_refresh_signal.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/models/circle_comment.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/utils/open_circle_post.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';
import 'package:hilmi/widgets/common/comment_more_sheet.dart';

class CirclePostDetailController extends GetxController {
  CirclePostDetailController({
    required this.post,
    required bool initialFollowed,
    required bool initialLiked,
    CircleRepository? repository,
  })  : repository = repository ?? const CircleRepository() {
    isFollowed.value = initialFollowed;
    isLiked.value = initialLiked;
  }

  final CirclePost post;
  final CircleRepository repository;

  final isFollowed = false.obs;
  final isLiked = false.obs;
  final comments = <CircleComment>[].obs;
  final loadingComments = true.obs;
  final sendingComment = false.obs;

  final commentController = TextEditingController();
  final commentScrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    unawaited(loadComments());
    prefetchVideoSignature();
  }

  @override
  void onClose() {
    commentScrollController.dispose();
    commentController.dispose();
    super.onClose();
  }

  void prefetchVideoSignature() {
    for (final item in post.media) {
      if (item.isVideo && item.videoPath != null && item.videoPath!.isNotEmpty) {
        repository.prefetchVideoSignature(item.videoPath);
        break;
      }
    }
  }

  void scrollCommentsToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || !commentScrollController.hasClients) return;
      final pos = commentScrollController.position;
      final target = pos.maxScrollExtent;
      if (animated) {
        commentScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        commentScrollController.jumpTo(target);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed || !commentScrollController.hasClients) return;
        final p = commentScrollController.position;
        if (p.pixels < p.maxScrollExtent - 2) {
          commentScrollController.jumpTo(p.maxScrollExtent);
        }
      });
    });
  }

  Future<void> loadComments() async {
    final loaded = await repository.fetchComments(post.id);
    if (isClosed) return;
    comments.assignAll(
      loaded.where((c) => !BlockService.isBlocked(c.authorId)).toList(),
    );
    loadingComments.value = false;
    if (comments.isNotEmpty) {
      scrollCommentsToEnd(animated: false);
    }
  }

  void popWithResult(BuildContext context, {bool deleted = false}) {
    Navigator.of(context).pop(
      CirclePostDetailResult(
        isFollowed: isFollowed.value,
        isLiked: isLiked.value,
        deleted: deleted,
      ),
    );
  }

  Future<void> onFollowTap(BuildContext context) async {
    if (!await ensureLoggedIn(
      context,
      loginHint: 'Please sign in to follow',
    )) {
      return;
    }
    if (isClosed) return;
    try {
      final following = await FollowService.toggle(post.authorId);
      if (isClosed) return;
      isFollowed.value = following;
    } catch (error) {
      if (isClosed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> onLikeTap(BuildContext context) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      if (isClosed || !AuthService.isLoggedIn) return;
      isLiked.value = LikeService.isLiked(post.id);
      return;
    }
    isLiked.value = !isLiked.value;
    try {
      final liked = await LikeService.toggle(post.id);
      if (isClosed) return;
      isLiked.value = liked;
      ProfileRefreshSignal.notify();
    } catch (error) {
      if (isClosed) return;
      isLiked.value = LikeService.isLiked(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> onMoreTap(BuildContext context) async {
    final result = await CirclePostMoreSheet.show(
      context,
      post: post,
      repository: repository,
    );
    if (isClosed || result == null) return;
    if (result == CirclePostMoreResult.deleted) {
      popWithResult(context, deleted: true);
      return;
    }
    if (result == CirclePostMoreResult.blacklisted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> deleteOwnComment(CircleComment comment) async {
    return repository.deleteComment(comment.id);
  }

  Future<void> onCommentTap(BuildContext context, CircleComment comment) async {
    final isOwn = CommentMoreSheet.isOwnSender(comment.authorId);
    final result = await CommentMoreSheet.showForMessage(
      context,
      isOwn: isOwn,
      senderUserId: comment.authorId,
      deleteMessage: isOwn ? () => deleteOwnComment(comment) : null,
    );
    if (isClosed || result == null) return;
    if (result == CommentMoreResult.deleted) {
      comments.removeWhere((c) => c.id == comment.id);
      return;
    }
    if (result == CommentMoreResult.blacklisted) {
      comments.removeWhere(
        (c) => BlockService.isBlocked(c.authorId),
      );
    }
  }

  Future<void> onSendComment(BuildContext context) async {
    final text = commentController.text.trim();
    if (text.isEmpty || sendingComment.value) return;

    if (!await ensureLoggedIn(
      context,
      loginHint: 'Please sign in to comment',
    )) {
      return;
    }
    if (isClosed) return;

    sendingComment.value = true;
    try {
      final comment = await repository.sendComment(
        postId: post.id,
        content: text,
      );
      if (isClosed) return;
      commentController.clear();
      dismissKeyboard(context);
      sendingComment.value = false;
      if (!BlockService.isBlocked(comment.authorId)) {
        comments.add(comment);
      }
      scrollCommentsToEnd();
    } catch (error) {
      debugPrint('[CirclePostDetailController] send comment: $error');
      if (isClosed) return;
      sendingComment.value = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send comment: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
