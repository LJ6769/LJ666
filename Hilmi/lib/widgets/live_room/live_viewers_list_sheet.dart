// 直播间观众列表底部弹层。
import 'package:flutter/material.dart';
import 'package:hilmi/data/live_viewers_repository.dart';
import 'package:hilmi/models/live_viewer.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/follow/follow_action_button.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

/// 直播间观众列表底部弹层（点击礼物旁观众按钮打开）。
class LiveViewersListSheet extends StatefulWidget {
  const LiveViewersListSheet({
    super.key,
    required this.scale,
    this.streamerId,
    this.currentViewerId,
    this.initialViewers,
    this.viewersRepository = const LiveViewersRepository(),
  });

  final double scale;
  final String? streamerId;

  /// 进房观众身份（与 [FollowActionButton.isSelfUserId] 互补，避免资料未缓存时误判）。
  final String? currentViewerId;
  final List<LiveViewer>? initialViewers;
  final LiveViewersRepository viewersRepository;

  static const _designWidth = 375.0;
  static const _panelColor = Color(0xFFFDF9ED);
  static const _gridColumns = 4;
  static const _closeBarHeight = 40.0;
  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    String? streamerId,
    String? currentViewerId,
    List<LiveViewer>? viewers,
    LiveViewersRepository viewersRepository = const LiveViewersRepository(),
  }) async {
    if (_isShowing || !context.mounted) return;
    _isShowing = true;

    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        isScrollControlled: true,
        enableDrag: true,
        useSafeArea: false,
        builder: (context) => LiveViewersListSheet(
          scale: scale,
          streamerId: streamerId,
          currentViewerId: currentViewerId,
          initialViewers: viewers,
          viewersRepository: viewersRepository,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<LiveViewersListSheet> createState() => _LiveViewersListSheetState();
}

class _LiveViewersListSheetState extends State<LiveViewersListSheet> {
  List<LiveViewer> _viewers = [];
  bool _loading = true;
  double get _s => widget.scale;

  bool _isSelfViewer(String viewerId) {
    if (FollowActionButton.isSelfUserId(viewerId)) return true;
    final mine = widget.currentViewerId?.trim();
    if (mine == null || mine.isEmpty) return false;
    return mine == viewerId.trim();
  }

  @override
  void initState() {
    super.initState();
    final preset = widget.initialViewers;
    if (preset != null) {
      _viewers = preset
          .where((v) => !BlockService.isBlocked(v.id))
          .toList(growable: false);
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final list = await widget.viewersRepository.fetchViewers(
      excludeUserId: widget.streamerId,
    );
    if (!mounted) return;
    setState(() {
      _viewers = list
          .where((v) => !BlockService.isBlocked(v.id))
          .toList(growable: false);
      _loading = false;
    });
  }

  void _onFollowTap(LiveViewer viewer) {
    if (_isSelfViewer(viewer.id)) return;
    FollowActionButton.handleTap(context, viewer.id);
  }

  void _onViewerAvatarTap(LiveViewer viewer) {
    final id = viewer.id.trim();
    if (id.isEmpty) return;
    Navigator.of(context).pop();
    openStarProfileForUser(
      context,
      userId: id,
      name: viewer.displayName,
      imageUrl: viewer.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final closeSize = LiveViewersListSheet._closeBarHeight * _s;

    return Padding(
      padding: EdgeInsets.only(top: 56 * _s),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.only(bottom: bottomPad + 4 * _s),
            decoration: BoxDecoration(
              color: LiveViewersListSheet._panelColor,
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
                        LiveRoomAssets.viewersListTitle,
                        height: 30 * _s,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Image.asset(
                          LiveRoomAssets.viewersListClose,
                          height: closeSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 48 * _s),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD14D4D),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_viewers.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16 * _s, 0, 16 * _s, 32 * _s),
        child: Text(
          'No viewers yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.45),
            fontSize: 14 * _s,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final hPad = 14 * _s;
    final hGap = 10 * _s;
    final vGap = 12 * _s;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 14 * _s),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final innerW = constraints.maxWidth;
          final cellW =
              (innerW - hGap * (LiveViewersListSheet._gridColumns - 1)) /
                  LiveViewersListSheet._gridColumns;
          final photoH = cellW * 1.32;

          return ValueListenableBuilder<Set<String>>(
            valueListenable: FollowService.followedIds,
            builder: (context, followedIds, _) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: LiveViewersListSheet._gridColumns,
                  mainAxisSpacing: vGap,
                  crossAxisSpacing: hGap,
                  mainAxisExtent: photoH,
                ),
                itemCount: _viewers.length,
                itemBuilder: (context, index) {
                  final viewer = _viewers[index];
                  return _ViewerGridCell(
                    scale: _s,
                    viewer: viewer,
                    showFollow: !_isSelfViewer(viewer.id),
                    isFollowed: followedIds.contains(viewer.id),
                    onFollowTap: () => _onFollowTap(viewer),
                    onAvatarTap: () => _onViewerAvatarTap(viewer),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ViewerGridCell extends StatelessWidget {
  const _ViewerGridCell({
    required this.scale,
    required this.viewer,
    required this.showFollow,
    required this.isFollowed,
    required this.onFollowTap,
    required this.onAvatarTap,
  });

  final double scale;
  final LiveViewer viewer;
  final bool showFollow;
  final bool isFollowed;
  final VoidCallback onFollowTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final radius = 12 * scale;
    final borderW = 2.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          behavior: HitTestBehavior.opaque,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE8E0D0),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.black, width: borderW),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - borderW),
              child: viewer.avatarUrl != null && viewer.avatarUrl!.isNotEmpty
                  ? CachedMediaImage(
                      url: viewer.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholder(scale),
                    )
                  : _placeholder(scale),
            ),
          ),
        ),
        if (showFollow)
          Positioned(
            left: 5 * scale,
            right: 5 * scale,
            bottom: 7 * scale,
            child: GestureDetector(
              onTap: onFollowTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                isFollowed
                    ? LiveRoomAssets.viewersListFollowed
                    : LiveRoomAssets.viewersListFollowAdd,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder(double s) {
    return ColoredBox(
      color: const Color(0xFFD9CFC0),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 32 * s,
          color: Colors.black.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
