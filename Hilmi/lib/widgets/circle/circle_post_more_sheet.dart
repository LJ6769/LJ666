import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/data/circle_repository.dart';
import 'package:hilmi/models/circle_post.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/circle/circle_delete_post_dialog.dart';
import 'package:hilmi/utils/block_user_flow.dart';
import 'package:hilmi/widgets/live_room/live_report_sheet.dart';

/// 朋友圈「更多」操作结果。
enum CirclePostMoreResult {
  deleted,
  blacklisted,
}

/// 朋友圈帖子「更多」底部弹层。
class CirclePostMoreSheet extends StatelessWidget {
  const CirclePostMoreSheet({
    super.key,
    required this.scale,
    required this.isOwnPost,
    this.targetUserId,
    this.postId,
    this.repository = const CircleRepository(),
  });

  final double scale;
  final bool isOwnPost;
  final String? targetUserId;
  final String? postId;
  final CircleRepository repository;

  static const _designWidth = 375.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static bool _isOwnPost(CirclePost post) {
    final authorId = post.authorId.trim();
    final selfId = AuthService.cachedProfile?.id.trim() ?? '';
    return authorId.isNotEmpty && selfId.isNotEmpty && authorId == selfId;
  }

  /// 打开帖子更多菜单。
  static Future<CirclePostMoreResult?> show(
    BuildContext context, {
    required CirclePost post,
    CircleRepository repository = const CircleRepository(),
  }) async {
    if (AuthService.isLoggedIn && AuthService.cachedProfile == null) {
      await AuthService.loadCurrentProfile();
    }
    if (!context.mounted) return null;
    if (_isOwnPost(post)) {
      return _showOwnPostSheet(
        context,
        post: post,
        repository: repository,
      );
    }
    return _showOthersSheet(context, userId: post.authorId);
  }

  /// 按用户 ID 打开（私信等）：举报 / 拉黑。
  static Future<CirclePostMoreResult?> showForUser(
    BuildContext context, {
    required String userId,
  }) =>
      _showOthersSheet(context, userId: userId);

  static Future<CirclePostMoreResult?> _showOwnPostSheet(
    BuildContext context, {
    required CirclePost post,
    required CircleRepository repository,
  }) async {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    return showModalBottomSheet<CirclePostMoreResult>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => CirclePostMoreSheet(
        scale: scale,
        isOwnPost: true,
        postId: post.id,
        repository: repository,
      ),
    );
  }

  static Future<CirclePostMoreResult?> _showOthersSheet(
    BuildContext context, {
    required String userId,
  }) async {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final blacklisted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => CirclePostMoreSheet(
        scale: scale,
        isOwnPost: false,
        targetUserId: userId,
      ),
    );
    return blacklisted == true ? CirclePostMoreResult.blacklisted : null;
  }

  double get _s => scale;

  Future<void> _onDeletePost(BuildContext context) async {
    final id = postId?.trim() ?? '';
    if (id.isEmpty) return;

    final confirmed = await CircleDeletePostDialog.show(context);
    if (confirmed != true || !context.mounted) return;

    try {
      final ok = await repository.deletePost(id);
      if (!context.mounted) return;
      if (ok) {
        Navigator.of(context).pop(CirclePostMoreResult.deleted);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onReport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final hostContext = Navigator.of(context).context;
    Navigator.of(context).pop();
    await LiveReportSheet.show(hostContext, scaffoldMessenger: messenger);
  }

  Future<void> _onBlacklist(BuildContext context) async {
    final id = targetUserId?.trim() ?? '';
    if (id.isEmpty) return;
    final added = await addUserToBlacklist(context, id);
    if (!added || !context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(top: 56 * _s),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.only(bottom: bottomPad + 4 * _s),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20 * _s)),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16 * _s, 14 * _s, 12 * _s, 16 * _s),
                  child: Row(
                    children: [
                      if (!isOwnPost)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              CircleAssets.moreTitleAbout,
                              height: 30 * _s,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Image.asset(
                          CircleAssets.moreBtnClose,
                          width: 40 * _s,
                          height: 40 * _s,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwnPost)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 14 * _s),
                    child: _ActionRow(
                      scale: _s,
                      iconAsset: CircleAssets.moreIcDelete,
                      label: 'Delete Post',
                      onTap: () => _onDeletePost(context),
                    ),
                  )
                else ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 10 * _s),
                    child: _ActionRow(
                      scale: _s,
                      iconAsset: CircleAssets.moreIcReport,
                      label: 'Report',
                      onTap: () => _onReport(context),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 14 * _s),
                    child: _ActionRow(
                      scale: _s,
                      iconAsset: CircleAssets.moreIcBlacklist,
                      label: 'Add to Blacklist',
                      onTap: () => _onBlacklist(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.scale,
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final double scale;
  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 52 * s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              CircleAssets.moreActionRowBg,
              fit: BoxFit.fill,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14 * s),
              child: Row(
                children: [
                  Image.asset(
                    iconAsset,
                    width: 32 * s,
                    height: 32 * s,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w800,
                      ),
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
