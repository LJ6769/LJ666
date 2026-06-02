import 'package:flutter/material.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/data/tipsy_bar_chat_repository.dart';
import 'package:hilmi/utils/block_user_flow.dart';
import 'package:hilmi/widgets/live_room/live_report_sheet.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_chat_assets.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_delete_room_dialog.dart';

/// Tipsy Bar 聊天室「更多」操作结果。
enum TipsyBarMoreResult {
  deleted,
  blacklisted,
}

/// Tipsy Bar 聊天室「更多」：房主仅 Delete Room；访客为 Report / Blacklist。
class TipsyBarAboutRoomSheet extends StatelessWidget {
  const TipsyBarAboutRoomSheet({
    super.key,
    required this.scale,
    required this.title,
    required this.intro,
    required this.isRoomHost,
    this.roomId,
    this.hostUserId = '',
    this.repository = const TipsyBarChatRepository(),
  });

  final double scale;
  final String title;
  final String intro;
  final bool isRoomHost;
  final String? roomId;
  final String hostUserId;
  final TipsyBarChatRepository repository;

  static const _designWidth = 375.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static const _defaultIntro =
      'Making friends over drinks—chatting about cocktails, swapping stories '
      'about life—a late-night gathering spot for fellow spirits enthusiasts.';

  static bool _isRoomHost(String? hostUserId) {
    final hostId = hostUserId?.trim() ?? '';
    final selfId = AuthService.cachedProfile?.id.trim() ?? '';
    return hostId.isNotEmpty && selfId.isNotEmpty && hostId == selfId;
  }

  /// 打开聊天室更多菜单。
  static Future<TipsyBarMoreResult?> show(
    BuildContext context, {
    required String roomId,
    required String title,
    String? intro,
    required String? hostUserId,
    TipsyBarChatRepository repository = const TipsyBarChatRepository(),
  }) async {
    if (AuthService.isLoggedIn && AuthService.cachedProfile == null) {
      await AuthService.loadCurrentProfile();
    }
    if (!context.mounted) return null;

    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final roomTitle = title.trim().isNotEmpty ? title.trim() : 'Tipsy Bar Room';
    final roomIntro = intro?.trim();
    final hostId = hostUserId?.trim() ?? '';
    final isHost = _isRoomHost(hostId);

    if (isHost) {
      final deleted = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        isScrollControlled: true,
        enableDrag: true,
        useSafeArea: false,
        builder: (context) => TipsyBarAboutRoomSheet(
          scale: scale,
          title: roomTitle,
          intro: roomIntro != null && roomIntro.isNotEmpty
              ? roomIntro
              : _defaultIntro,
          isRoomHost: true,
          roomId: roomId,
          repository: repository,
        ),
      );
      return deleted == true ? TipsyBarMoreResult.deleted : null;
    }

    final blacklisted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => TipsyBarAboutRoomSheet(
        scale: scale,
        title: roomTitle,
        intro:
            roomIntro != null && roomIntro.isNotEmpty ? roomIntro : _defaultIntro,
        isRoomHost: false,
        hostUserId: hostId,
        repository: repository,
      ),
    );
    return blacklisted == true ? TipsyBarMoreResult.blacklisted : null;
  }

  double get _s => scale;

  Future<void> _onDeleteRoom(BuildContext context) async {
    final id = roomId?.trim() ?? '';
    if (id.isEmpty) return;

    final confirmed = await TipsyBarDeleteRoomDialog.show(context);
    if (confirmed != true || !context.mounted) return;

    try {
      final ok = await repository.deleteRoom(id);
      if (!context.mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
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
    if (hostUserId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host info is unavailable'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final added = await addUserToBlacklist(context, hostUserId);
    if (!added || !context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(top: 48 * _s),
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
                if (isRoomHost) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(16 * _s, 14 * _s, 12 * _s, 8 * _s),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Image.asset(
                          TipsyBarChatAssets.aboutRoomClose,
                          width: 40 * _s,
                          height: 40 * _s,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 14 * _s),
                    child: _ActionRow(
                      scale: _s,
                      iconAsset: TipsyBarChatAssets.aboutRoomIcDeleteRoom,
                      label: 'Delete Room',
                      onTap: () => _onDeleteRoom(context),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(16 * _s, 14 * _s, 12 * _s, 12 * _s),
                    child: Row(
                      children: [
                        Image.asset(
                          TipsyBarChatAssets.aboutRoomTitle,
                          height: 32 * _s,
                          fit: BoxFit.contain,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Image.asset(
                            TipsyBarChatAssets.aboutRoomClose,
                            width: 40 * _s,
                            height: 40 * _s,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 12 * _s),
                    child: _InfoCard(
                      scale: _s,
                      title: title,
                      intro: intro,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 8 * _s),
                    child: _ActionRow(
                      scale: _s,
                      iconAsset: TipsyBarChatAssets.aboutRoomIcReport,
                      label: 'Report',
                      onTap: () => _onReport(context),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 14 * _s),
                    child: _ActionRow(
                      scale: _s,
                      iconAsset: TipsyBarChatAssets.aboutRoomIcBlacklist,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.scale,
    required this.title,
    required this.intro,
  });

  final double scale;
  final String title;
  final String intro;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            TipsyBarChatAssets.aboutRoomInfoCardBg,
            fit: BoxFit.fill,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledText(
                scale: s,
                label: 'Titile',
                body: title,
              ),
              SizedBox(height: 10 * s),
              _LabeledText(
                scale: s,
                label: 'Intro',
                body: intro,
                maxLines: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({
    required this.scale,
    required this.label,
    required this.body,
    this.maxLines,
  });

  final double scale;
  final String label;
  final String body;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final labelStyle = TextStyle(
      color: Colors.black,
      fontSize: 15 * s,
      fontWeight: FontWeight.w800,
      height: 1.35,
    );
    final bodyStyle = TextStyle(
      color: const Color(0xFF424242),
      fontSize: 14 * s,
      fontWeight: FontWeight.w500,
      height: 1.45,
    );

    return RichText(
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(
        style: bodyStyle,
        children: [
          TextSpan(text: '$label: ', style: labelStyle),
          TextSpan(text: body),
        ],
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
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              TipsyBarChatAssets.aboutRoomActionRowBg,
              fit: BoxFit.fill,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14 * s),
              child: Row(
                children: [
                  Image.asset(
                    iconAsset,
                    width: 36 * s,
                    height: 36 * s,
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
