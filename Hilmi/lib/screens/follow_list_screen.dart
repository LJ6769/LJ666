import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/models/follow_user.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/open_direct_chat.dart';
import 'package:hilmi/utils/open_direct_video_call.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/follow/follow_assets.dart';
import 'package:hilmi/widgets/follow/follow_user_list_row.dart';

/// 我的关注列表（设置 → Follow）。
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key});

  static const _designWidth = 375.0;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<FollowUser> _users = [];
  bool _loading = true;
  String? _togglingUserId;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / FollowListScreen._designWidth;

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
      final users = await FollowService.loadFollowingUsers();
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

  Future<void> _onUnfollow(FollowUser user) async {
    if (_togglingUserId != null) return;
    setState(() => _togglingUserId = user.id);
    try {
      final stillFollowing = await FollowService.toggle(user.id);
      if (!mounted) return;
      if (!stillFollowing) {
        setState(() => _users = _users.where((u) => u.id != user.id).toList());
      }
    } catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (mounted) setState(() => _togglingUserId = null);
    }
  }

  Future<void> _onMessageTap(FollowUser user) async {
    if (!AuthService.isLoggedIn) {
      await openLoginScreen(context);
      return;
    }
    if (!mounted) return;
    await openDirectChat(context, peer: user.toDirectChatPeer());
  }

  Future<void> _onVideoTap(FollowUser user) async {
    await openDirectVideoCall(context, peer: user.toDirectChatPeer());
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
                    'Follow',
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
                            'No followed users yet',
                            style: TextStyle(
                              fontSize: 15 * s,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.45),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(20 * s, 0, 20 * s, 24 * s),
                          itemCount: _users.length,
                          separatorBuilder: (_, _) => SizedBox(height: 10 * s),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final busy = _togglingUserId == user.id;
                            return FollowUserListRow(
                              scale: s,
                              user: user,
                              onVideoTap: () => _onVideoTap(user),
                              onMessageTap: () => _onMessageTap(user),
                              followButton: FollowListFollowButtonSlot(
                                scale: s,
                                child: GestureDetector(
                                  onTap: busy ? null : () => _onUnfollow(user),
                                  behavior: HitTestBehavior.opaque,
                                  child: Opacity(
                                    opacity: busy ? 0.5 : 1,
                                    child: Image.asset(
                                      FollowAssets.btnFollowed,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
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
