// 我的粉丝列表（设置 → Followers）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/followers_list_controller.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/follow/follow_assets.dart';
import 'package:hilmi/widgets/follow/follow_user_list_row.dart';
import 'package:hilmi/widgets/home_feed_cards.dart';

/// 我的粉丝列表（设置 → Followers；数据来自 User.follower_ids）。
class FollowersListScreen extends StatelessWidget {
  const FollowersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetxScreen<FollowersListController>(
      create: () => FollowersListController(),
      builder: (c) => Obx(() {
        final s =
            MediaQuery.sizeOf(context).width / FollowersListController.designWidth;
        final topInset = MediaQuery.paddingOf(context).top;
        final users = c.users;
        final loading = c.loading.value;
        final togglingUserId = c.togglingUserId.value;
        final _ = c.followIdsVersion.value;
        final followedIds = FollowService.followedIds.value;

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
                        'Followers',
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
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD14D4D),
                            strokeWidth: 2,
                          ),
                        )
                      : users.isEmpty
                          ? const Center(
                              child: HomeFeedEmptyPlaceholder(),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                  20 * s, 0, 20 * s, 24 * s),
                              itemCount: users.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: 10 * s),
                              itemBuilder: (context, index) {
                                final user = users[index];
                                final isFollowing =
                                    followedIds.contains(user.id);
                                final busy = togglingUserId == user.id;

                                return FollowUserListRow(
                                  scale: s,
                                  user: user,
                                  onVideoTap: () => c.onVideoTap(context, user),
                                  onMessageTap: () =>
                                      c.onMessageTap(context, user),
                                  followButton: FollowListFollowButtonSlot(
                                    scale: s,
                                    child: GestureDetector(
                                      onTap: busy
                                          ? null
                                          : () => c.onFollowTap(context, user),
                                      behavior: HitTestBehavior.opaque,
                                      child: Opacity(
                                        opacity: busy ? 0.5 : 1,
                                        child: Image.asset(
                                          isFollowing
                                              ? FollowAssets.btnFollowed
                                              : FollowAssets.btnFollowAdd,
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
      }),
    );
  }
}
