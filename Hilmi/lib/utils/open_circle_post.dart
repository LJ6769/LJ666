import 'package:flutter/material.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/screens/circle_post_detail_screen.dart';

/// 打开朋友圈帖子详情。
Future<CirclePostDetailResult?> openCirclePostDetail(
  BuildContext context, {
  required CirclePost post,
  required bool isFollowed,
  required bool isLiked,
}) {
  return Navigator.of(context).push<CirclePostDetailResult>(
    MaterialPageRoute(
      builder: (_) => CirclePostDetailScreen(
        post: post,
        initialFollowed: isFollowed,
        initialLiked: isLiked,
      ),
    ),
  );
}

class CirclePostDetailResult {
  const CirclePostDetailResult({
    required this.isFollowed,
    required this.isLiked,
    this.deleted = false,
  });

  final bool isFollowed;
  final bool isLiked;

  /// 帖子已在详情内删除，调用方应从列表移除。
  final bool deleted;
}
