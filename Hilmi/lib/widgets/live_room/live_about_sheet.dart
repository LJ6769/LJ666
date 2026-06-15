// 直播间 About：简介、标签、举报、拉黑。
import 'package:flutter/material.dart';
import 'package:hilmi/utils/block_user_flow.dart';
import 'package:hilmi/widgets/live_room/live_report_sheet.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

/// 直播间「更多」/ About Live：简介 + 标签 + 举报 / 拉黑。
class LiveAboutSheet extends StatelessWidget {
  const LiveAboutSheet({
    super.key,
    required this.scale,
    required this.description,
    required this.tags,
    required this.streamerId,
  });

  final double scale;
  final String description;
  final List<String> tags;
  final String streamerId;

  static const _designWidth = 375.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static const _defaultDescription =
      "Hey everyone, welcome to my bartending live stream! Today, we're diving "
      'into the art of cocktail-making, from classic recipes to creative twists. '
      "Whether you're a seasoned mixologist or just starting out, there's something "
      'for everyone. Grab your shaker and join the fun!';

  /// 拉黑成功时返回 `true`。
  static Future<bool> show(
    BuildContext context, {
    String? description,
    List<String> tags = const [],
    required String? streamerId,
  }) async {
    final id = streamerId?.trim() ?? '';
    if (id.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host info is unavailable. Please try again later.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final desc = description?.trim();

    final blacklisted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: false,
      builder: (context) => LiveAboutSheet(
        scale: scale,
        description:
            desc != null && desc.isNotEmpty ? desc : _defaultDescription,
        tags: tags,
        streamerId: id,
      ),
    );
    return blacklisted ?? false;
  }

  double get _s => scale;

  Future<void> _onReport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final hostContext = Navigator.of(context).context;
    Navigator.of(context).pop();
    await LiveReportSheet.show(hostContext, scaffoldMessenger: messenger);
  }

  Future<void> _onBlacklist(BuildContext context) async {
    final added = await addUserToBlacklist(context, streamerId);
    if (!added || !context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final closeSize = 40 * _s;

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
                      Image.asset(
                        LiveRoomAssets.aboutTitle,
                        height: 30 * _s,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Image.asset(
                          LiveRoomAssets.aboutClose,
                          height: closeSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 10 * _s),
                  child: _ContentCard(
                    scale: _s,
                    description: description,
                    tags: tags,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 10 * _s),
                  child: _ActionRow(
                    scale: _s,
                    iconAsset: LiveRoomAssets.aboutIcReport,
                    label: 'Report',
                    onTap: () => _onReport(context),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14 * _s, 0, 14 * _s, 14 * _s),
                  child: _ActionRow(
                    scale: _s,
                    iconAsset: LiveRoomAssets.aboutIcBlacklist,
                    label: 'Add to Blacklist',
                    onTap: () => _onBlacklist(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.scale,
    required this.description,
    required this.tags,
  });

  final double scale;
  final String description;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return Container(
      padding: EdgeInsets.fromLTRB(14 * s, 14 * s, 14 * s, 12 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 120 * s),
            child: SingleChildScrollView(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: const Color(0xFF424242),
                    fontSize: 14 * s,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: 'Content: ',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15 * s,
                      ),
                    ),
                    TextSpan(text: description),
                  ],
                ),
              ),
            ),
          ),
          if (tags.isNotEmpty) ...[
            SizedBox(height: 12 * s),
            Wrap(
              spacing: 8 * s,
              runSpacing: 8 * s,
              children: [
                for (var i = 0; i < tags.length; i++)
                  _TagChip(label: tags[i], index: i, scale: s),
              ],
            ),
          ],
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              LiveRoomAssets.aboutActionRowBg,
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

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.index,
    required this.scale,
  });

  final String label;
  final int index;
  final double scale;

  static const _palette = [
    Color(0xFFE57373),
    Color(0xFFBA68C8),
    Color(0xFFFFD54F),
    Color(0xFF81C784),
  ];

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final bg = _palette[index % _palette.length];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20 * s),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.black,
          fontSize: 12 * s,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
