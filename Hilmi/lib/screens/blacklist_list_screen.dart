import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/blacklist/blacklist_assets.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/follow/follow_assets.dart';
import 'package:hilmi/widgets/follow/follow_user_list_row.dart';

/// 黑名单列表（设置 → Blacklist）。
class BlacklistListScreen extends StatefulWidget {
  const BlacklistListScreen({super.key});

  static const _designWidth = 375.0;

  @override
  State<BlacklistListScreen> createState() => _BlacklistListScreenState();
}

class _BlacklistListScreenState extends State<BlacklistListScreen> {
  List<FollowUser> _users = [];
  bool _loading = true;
  String? _removingUserId;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / BlacklistListScreen._designWidth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _users = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final users = await BlockService.loadBlockedUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    }
  }

  Future<void> _onRemove(FollowUser user) async {
    if (_removingUserId != null) return;
    setState(() => _removingUserId = user.id);
    try {
      final stillBlocked = await BlockService.unblock(user.id);
      if (!mounted) return;
      if (!stillBlocked) {
        setState(() => _users = _users.where((u) => u.id != user.id).toList());
      }
    } catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (mounted) setState(() => _removingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: splashBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: splashBackground,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topInset + 8 * s),
            SizedBox(
              height: 44 * s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    'Blacklist',
                    style: TextStyle(
                      fontSize: 18 * s,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  AuthTopBarButton(
                    top: 2 * s,
                    left: 16 * s,
                    size: 40 * s,
                    asset: FollowAssets.btnBack,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12 * s),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD14D4D),
                        strokeWidth: 2,
                      ),
                    )
                  : _users.isEmpty
                      ? Center(
                          child: Text(
                            'No blocked users',
                            style: TextStyle(
                              fontSize: 15 * s,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding:
                              EdgeInsets.fromLTRB(20 * s, 0, 20 * s, 24 * s),
                          itemCount: _users.length,
                          separatorBuilder: (_, _) => SizedBox(height: 10 * s),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final busy = _removingUserId == user.id;
                            return _BlacklistUserRow(
                              scale: s,
                              user: user,
                              busy: busy,
                              onRemove: () => _onRemove(user),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlacklistUserRow extends StatelessWidget {
  const _BlacklistUserRow({
    required this.scale,
    required this.user,
    required this.busy,
    required this.onRemove,
  });

  final double scale;
  final FollowUser user;
  final bool busy;
  final VoidCallback onRemove;

  static const _removeAspect = 270 / 108;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / FollowUserListRow.rowAspect;

        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                FollowAssets.rowBg,
                width: width,
                height: height,
                fit: BoxFit.fill,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12 * s),
                child: Row(
                  children: [
                    _Avatar(scale: s, user: user),
                    SizedBox(width: 10 * s),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16 * s,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 2 * s),
                          Text(
                            user.handle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13 * s,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: busy ? null : onRemove,
                      behavior: HitTestBehavior.opaque,
                      child: Opacity(
                        opacity: busy ? 0.5 : 1,
                        child: SizedBox(
                          width: 90 * s,
                          height: 90 * s / _removeAspect,
                          child: Image.asset(
                            BlacklistAssets.btnRemove,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
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
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.scale, required this.user});

  final double scale;
  final FollowUser user;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final size = 48 * s;
    final radius = 12 * s;

    Widget child;
    if (user.hasAvatar && user.avatarUrl != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedMediaImage(
          url: user.avatarUrl!,
          cacheKey: user.avatarPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _placeholder(size, radius),
        ),
      );
    } else {
      child = _placeholder(size, radius);
    }

    return SizedBox(width: size, height: size, child: child);
  }

  Widget _placeholder(double size, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        FollowAssets.avatarPlaceholder,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
