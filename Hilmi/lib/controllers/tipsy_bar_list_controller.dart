// Tipsy Bar 房间列表页状态与导航逻辑。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/data/home_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/utils/open_tipsy_bar_about_sheet.dart';
import 'package:hilmi/utils/open_tipsy_bar_chat_room.dart';
import 'package:hilmi/utils/open_tipsy_create_room.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_about_room_sheet.dart';

class TipsyBarListController extends GetxController {
  TipsyBarListController({HomeRepository? repository})
      : _repository = repository ?? const HomeRepository();

  final HomeRepository _repository;

  final rooms = <TipsyBarRoom>[].obs;
  final loading = false.obs;
  final loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    unawaited(loadRooms());
  }

  @override
  void onClose() {
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    super.onClose();
  }

  void _onBlockedIdsChanged() {
    final pool = FeedDataCache.tipsyBarPool;
    if (pool != null) {
      rooms.assignAll(BlockService.filterTipsyBarRooms(pool));
      return;
    }
    rooms.assignAll(BlockService.filterTipsyBarRooms(rooms.toList()));
  }

  Future<void> loadRooms({bool forceRefresh = false}) async {
    if (!forceRefresh && loaded.value) return;

    if (!loaded.value || forceRefresh) {
      loading.value = true;
    }

    final list = await _repository.fetchTipsyBarList(
      forceRefresh: forceRefresh,
      blockedUserIds: BlockService.blockedIds.value,
    );
    if (isClosed) return;
    rooms.assignAll(list);
    loading.value = false;
    loaded.value = true;
  }

  void reloadRooms() {
    unawaited(loadRooms(forceRefresh: true));
  }

  Future<void> onCreateTap(BuildContext context) async {
    final room = await openTipsyCreateRoom(context);
    if (isClosed || room == null) return;
    reloadRooms();
    final deleted = await openTipsyBarChatRoom(context, room: room);
    if (isClosed) return;
    if (deleted) reloadRooms();
  }

  Future<void> openRoom(BuildContext context, TipsyBarRoom room) async {
    final deleted = await openTipsyBarChatRoom(context, room: room);
    if (isClosed) return;
    if (deleted) reloadRooms();
  }

  Future<void> openRoomAbout(BuildContext context, TipsyBarRoom room) async {
    final result = await openTipsyBarAboutSheet(context, room);
    if (isClosed) return;
    if (result == TipsyBarMoreResult.deleted) reloadRooms();
  }
}
