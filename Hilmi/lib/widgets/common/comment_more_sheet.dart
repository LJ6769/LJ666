// 评论/弹幕点击更多：自己的删除，他人的举报与拉黑。
import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/utils/block_user_flow.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/common/delete_comment_dialog.dart';
import 'package:hilmi/widgets/live_room/live_report_sheet.dart';

/// 评论更多操作结果。
enum CommentMoreResult {
  deleted,
  blacklisted,
}

/// 直播间 / 聊天室 / 朋友圈评论点击弹层。
abstract final class CommentMoreSheet {
  static const _designWidth = 375.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static bool isOwnSender(String? senderId) {
    final selfId = AuthService.cachedProfile?.id.trim() ?? '';
    final author = senderId?.trim() ?? '';
    return selfId.isNotEmpty && author.isNotEmpty && selfId == author;
  }

  /// 点击评论：根据是否本人弹出删除或举报/拉黑。
  static Future<CommentMoreResult?> showForMessage(
    BuildContext context, {
    required bool isOwn,
    String? senderUserId,
    Future<bool> Function()? deleteMessage,
  }) async {
    if (isOwn) {
      return _showOwnSheet(
        context,
        deleteMessage: deleteMessage,
      );
    }

    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return null;
    }
    if (AuthService.cachedProfile == null) {
      await AuthService.loadCurrentProfile();
    }
    if (!context.mounted) return null;

    return _showOthersSheet(
      context,
      userId: senderUserId,
    );
  }

  static Future<CommentMoreResult?> _showOwnSheet(
    BuildContext context, {
    Future<bool> Function()? deleteMessage,
  }) async {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    return showModalBottomSheet<CommentMoreResult>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => _CommentMoreSheetBody(
        scale: scale,
        isOwn: true,
        deleteMessage: deleteMessage,
      ),
    );
  }

  static Future<CommentMoreResult?> _showOthersSheet(
    BuildContext context, {
    String? userId,
  }) async {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final blacklisted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => _CommentMoreSheetBody(
        scale: scale,
        isOwn: false,
        targetUserId: userId,
      ),
    );
    return blacklisted == true ? CommentMoreResult.blacklisted : null;
  }
}

class _CommentMoreSheetBody extends StatelessWidget {
  const _CommentMoreSheetBody({
    required this.scale,
    required this.isOwn,
    this.targetUserId,
    this.deleteMessage,
  });

  final double scale;
  final bool isOwn;
  final String? targetUserId;
  final Future<bool> Function()? deleteMessage;

  double get _s => scale;

  Future<void> _onDelete(BuildContext context) async {
    final confirmed = await DeleteCommentDialog.show(context);
    if (confirmed != true || !context.mounted) return;

    try {
      final ok = deleteMessage != null ? await deleteMessage!() : false;
      if (!context.mounted) return;
      if (ok) {
        Navigator.of(context).pop(CommentMoreResult.deleted);
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
    final canBlacklist = !isOwn && (targetUserId?.trim().isNotEmpty ?? false);

    return Padding(
      padding: EdgeInsets.only(top: 56 * _s),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.only(bottom: bottomPad + 4 * _s),
            decoration: BoxDecoration(
              color: CommentMoreSheet._panelColor,
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
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Image.asset(
                            CircleAssets.moreTitleAbout,
                            height: 30 * _s,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
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
                if (isOwn)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 14 * _s),
                    child: _ActionRow(
                      scale: _s,
                      iconAsset: CircleAssets.moreIcDelete,
                      label: 'Delete Comment',
                      onTap: () => _onDelete(context),
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
                  if (canBlacklist)
                    Padding(
                      padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 14 * _s),
                      child: _ActionRow(
                        scale: _s,
                        iconAsset: CircleAssets.moreIcBlacklist,
                        label: 'Add to Blacklist',
                        onTap: () => _onBlacklist(context),
                      ),
                    )
                  else
                    SizedBox(height: 14 * _s),
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
              padding: EdgeInsets.symmetric(horizontal: 16 * s),
              child: Row(
                children: [
                  Image.asset(
                    iconAsset,
                    width: 28 * s,
                    height: 28 * s,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 12 * s),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w800,
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
