// Tipsy Bar 房间列表页（See All 进入）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/tipsy_bar_list_controller.dart';
import '../core/getx/getx_screen.dart';
import '../splash_page.dart';
import '../widgets/home_feed_cards.dart';
import '../widgets/tipsy/tipsy_create_banner.dart';

class TipsyBarListScreen extends StatelessWidget {
  const TipsyBarListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetxScreen<TipsyBarListController>(
      create: () => TipsyBarListController(),
      builder: (c) => Obx(() {
        final rooms = c.rooms.toList(growable: false);
        final loading = c.loading.value;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: splashBackground,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: splashBackground,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Image.asset(
                            'assets/home/tipsy_btn_back.png',
                            width: 44,
                            height: 44,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Tipsy Bar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  Expanded(
                    child: loading && rooms.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : rooms.isEmpty
                            ? CustomScrollView(
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      16,
                                    ),
                                    sliver: SliverToBoxAdapter(
                                      child: TipsyCreateBanner(
                                        onTap: () => c.onCreateTap(context),
                                      ),
                                    ),
                                  ),
                                  const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: HomeFeedEmptyPlaceholder(),
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 24),
                                children: [
                                  TipsyCreateBanner(
                                    onTap: () => c.onCreateTap(context),
                                  ),
                                  const SizedBox(height: 16),
                                  for (var i = 0; i < rooms.length; i++)
                                    HomeTipsyBarCard(
                                      room: rooms[i],
                                      photoOnRight: i.isOdd,
                                      isFirst: i == 0,
                                      isLast: i == rooms.length - 1,
                                      onJoinTap: () =>
                                          c.openRoom(context, rooms[i]),
                                      onMoreTap: () =>
                                          c.openRoomAbout(context, rooms[i]),
                                    ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
