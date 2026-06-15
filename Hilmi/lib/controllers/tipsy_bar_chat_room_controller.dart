// Tipsy Bar 语音聊天室：麦位、公屏、底部栏状态。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/foreground_media_pause.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/data/live_viewers_repository.dart';
import 'package:hilmi/data/tipsy_bar_chat_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/live_gift_send_result.dart';
import 'package:hilmi/models/live_viewer.dart';
import 'package:hilmi/models/tipsy_bar_chat.dart';
import 'package:hilmi/services/tipsy_bar_host_audio_player.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/common/comment_more_sheet.dart';
import 'package:hilmi/widgets/live_room/live_gift_shop_sheet.dart';
import 'package:hilmi/widgets/live_room/live_viewers_list_sheet.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_about_room_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TipsyBarChatRoomController extends GetxController {
  TipsyBarChatRoomController({
    required this.room,
    TipsyBarChatRepository? repository,
    this.openAboutRoomOnEnter = false,
  }) : repository = repository ?? const TipsyBarChatRepository();

  final TipsyBarRoom room;
  final TipsyBarChatRepository repository;
  final bool openAboutRoomOnEnter;

  static const viewersRepo = LiveViewersRepository();

  final detail = Rxn<TipsyBarChatRoomDetail>();
  final messages = <TipsyBarChatMessage>[].obs;
  final loading = true.obs;
  final soundOn = true.obs;
  final joinedSeat = false.obs;
  final micOn = true.obs;
  final giftNotificationName = RxnString();
  final giftNotificationAvatarUrl = RxnString();
  final giftNotificationGiftIcon = RxnString();
  final pendingAboutSheet = false.obs;

  final chatController = TextEditingController();
  final chatScrollController = ScrollController();
  final hostAudio = TipsyBarHostAudioPlayer();

  final knownMessageIds = <String>{};
  final roomVisitors = <String, LiveViewer>{};

  RealtimeChannel? _chatChannel;
  Timer? _giftNotificationTimer;
  bool _pendingAboutRoom = false;
  bool _resumeHostAudioAfterOverlay = false;
  late final ForegroundMediaHandle _foregroundMediaHandle;

  @override
  void onInit() {
    super.onInit();
    _foregroundMediaHandle = ForegroundMediaHandle(
      pause: () async {
        if (!soundOn.value) return;
        _resumeHostAudioAfterOverlay = true;
        await hostAudio.pause();
      },
      resume: () async {
        if (!_resumeHostAudioAfterOverlay || !soundOn.value || isClosed) {
          _resumeHostAudioAfterOverlay = false;
          return;
        }
        _resumeHostAudioAfterOverlay = false;
        await playHostAudio(
          detail.value?.hostAudioUrl,
          cacheKey: detail.value?.hostAudioPath,
        );
      },
    );
    ForegroundMediaPause.register(_foregroundMediaHandle);
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    _pendingAboutRoom = openAboutRoomOnEnter;
    unawaited(load());
  }

  @override
  void onClose() {
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    ForegroundMediaPause.unregister(_foregroundMediaHandle);
    _giftNotificationTimer?.cancel();
    _chatChannel?.unsubscribe();
    hostAudio.dispose();
    chatController.dispose();
    chatScrollController.dispose();
    super.onClose();
  }

  String? get currentUserId {
    final profileId = AuthService.cachedProfile?.id.trim();
    if (profileId != null && profileId.isNotEmpty) return profileId;
    final viewerId = ViewerSession.current?.id.trim();
    if (viewerId != null && viewerId.isNotEmpty) return viewerId;
    return null;
  }

  bool get isRoomHost {
    final hostId = detail.value?.host?.userId.trim() ?? '';
    final selfId = currentUserId ?? '';
    return hostId.isNotEmpty && selfId.isNotEmpty && hostId == selfId;
  }

  bool get roomInvolvesBlockedUser {
    final hostId = detail.value?.host?.userId ?? room.hostUserId;
    final memberIds = <String>[
      for (final id in room.participantUserIds) id,
      for (final member in detail.value?.members ?? const <TipsyBarChatMember>[])
        if (!member.isVacantSeat) member.userId,
    ];
    return BlockService.involvesBlockedUser(
      hostUserId: hostId,
      memberUserIds: memberIds,
    );
  }

  Future<void> openUserProfile(
    BuildContext context, {
    required String userId,
    String? name,
    String? email,
    String? imageUrl,
  }) async {
    await openStarProfileForUser(
      context,
      userId: userId,
      name: name,
      email: email,
      imageUrl: imageUrl,
    );
    if (isClosed || !context.mounted) return;
    if (BlockService.isBlocked(userId) || roomInvolvesBlockedUser) {
      leaveRoomAfterBlock(context);
    }
  }

  void _onBlockedIdsChanged() {
    if (isClosed) return;
    messages.removeWhere(
      (m) => m.senderId != null && BlockService.isBlocked(m.senderId),
    );
    for (final id in BlockService.blockedIds.value) {
      roomVisitors.remove(id);
    }
  }

  /// 拉黑后静默退出聊天室（个人页已关闭，此处只 pop 聊天室本身）。
  void leaveRoomAfterBlock(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> load() async {
    final loaded = await repository.fetchRoomDetail(room.id);
    if (isClosed) return;
    detail.value = loaded;
    loading.value = false;
    if (loaded != null) {
      await initRoomChat(loaded.id);
      await loadViewerProfile();
      registerSelfAsVisitor();
    } else {
      messages.assignAll([repository.communityTips()]);
    }
    if (isClosed) return;
    if (soundOn.value) {
      await playHostAudio(
        loaded?.hostAudioUrl,
        cacheKey: loaded?.hostAudioPath,
      );
    }
    if (_pendingAboutRoom) {
      _pendingAboutRoom = false;
      pendingAboutSheet.value = true;
    }
  }

  Future<void> initRoomChat(String roomId) async {
    await loadChatHistory(roomId);
    if (isClosed) return;
    subscribeRoomChat(roomId);
  }

  Future<void> loadChatHistory(String roomId) async {
    final history = await repository.fetchMessages(roomId);
    if (isClosed) return;

    final loaded = <TipsyBarChatMessage>[repository.communityTips()];
    for (final msg in history) {
      if (msg.senderId != null && BlockService.isBlocked(msg.senderId)) {
        continue;
      }
      final id = msg.id;
      if (id.isNotEmpty) {
        if (knownMessageIds.contains(id)) continue;
        knownMessageIds.add(id);
      }
      loaded.add(msg);
      trackVisitorFromMessage(msg);
    }

    messages.assignAll(loaded);
    scrollChatToEnd();
  }

  void subscribeRoomChat(String roomId) {
    if (!AppBootstrap.isReady || AppBootstrap.client == null) return;

    _chatChannel?.unsubscribe();
    _chatChannel = repository.subscribeInserts(
      roomId: roomId,
      onInsert: onRealtimeInsert,
    );
  }

  Future<void> onRealtimeInsert(Map<String, dynamic> record) async {
    final id = record['id'] as String?;
    if (id != null && knownMessageIds.contains(id)) return;

    TipsyBarChatMessage? message;
    if (id != null) {
      message = await repository.fetchMessageById(id);
    }
    message ??= TipsyBarChatMessage.fromRow(
      record,
      currentUserId: AuthService.cachedProfile?.id,
    );

    if (isClosed) return;
    appendMessage(message);
  }

  void appendMessage(TipsyBarChatMessage message) {
    if (message.senderId != null && BlockService.isBlocked(message.senderId)) {
      return;
    }
    final id = message.id;
    if (id.isNotEmpty) {
      if (knownMessageIds.contains(id)) return;
      knownMessageIds.add(id);
    }
    trackVisitorFromMessage(message);
    messages.add(message);
    scrollChatToEnd();
  }

  Future<bool> deleteOwnChatMessage(TipsyBarChatMessage message) async {
    final id = message.id.trim();
    if (id.isEmpty) return false;
    return repository.deleteMessage(id);
  }

  Future<void> onChatMessageTap(
    BuildContext context,
    TipsyBarChatMessage message,
  ) async {
    final result = await CommentMoreSheet.showForMessage(
      context,
      isOwn: message.isOwn,
      senderUserId: message.senderId,
      deleteMessage:
          message.isOwn ? () => deleteOwnChatMessage(message) : null,
    );
    if (isClosed || result == null) return;
    if (result == CommentMoreResult.deleted) {
      knownMessageIds.remove(message.id);
      messages.removeWhere((m) => m.id == message.id);
      return;
    }
    if (result == CommentMoreResult.blacklisted) {
      messages.removeWhere(
        (m) => m.senderId != null && BlockService.isBlocked(m.senderId),
      );
      if (roomInvolvesBlockedUser) {
        leaveRoomAfterBlock(context);
      }
    }
  }

  Future<void> playHostAudio(String? url, {String? cacheKey}) async {
    if (isClosed || url == null || url.trim().isEmpty) return;
    await hostAudio.playUrl(url, cacheKey: cacheKey);
  }

  Future<void> onSoundTap() async {
    final next = !soundOn.value;
    soundOn.value = next;
    if (next) {
      await playHostAudio(
        detail.value?.hostAudioUrl,
        cacheKey: detail.value?.hostAudioPath,
      );
    } else {
      await hostAudio.pause();
    }
  }

  void scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!chatScrollController.hasClients) return;
      chatScrollController.animateTo(
        chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> onSend(BuildContext context) async {
    final text = chatController.text.trim();
    if (text.isEmpty) return;

    if (!await ensureLoggedIn(
      context,
      loginHint: 'Please sign in to send messages',
    )) {
      return;
    }
    if (isClosed) return;

    final roomId = detail.value?.id ?? room.id;
    chatController.clear();

    try {
      final message = await repository.sendMessage(
        roomId: roomId,
        content: text,
      );
      if (isClosed) return;
      appendMessage(message);
    } catch (error) {
      if (isClosed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> onJoinSeat(BuildContext context) async {
    if (isRoomHost) return;

    if (!AuthService.isLoggedIn) {
      final loggedIn = await openLoginScreen(context);
      if (isClosed || loggedIn != true) return;
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }
    if (isClosed) return;
    joinedSeat.value = true;
    micOn.value = true;
    removeSelfFromAudience();
  }

  void onLeaveSeat() {
    joinedSeat.value = false;
    micOn.value = true;
    registerSelfAsVisitor();
  }

  void onMicTap() {
    if (!joinedSeat.value) return;
    micOn.value = !micOn.value;
  }

  Future<void> loadViewerProfile() async {
    if (!AuthService.isLoggedIn) return;
    await AuthService.loadCurrentProfile();
  }

  Future<void> onMoreTap(BuildContext context) async {
    final d = detail.value;
    final roomId = d?.id ?? room.id;
    final result = await TipsyBarAboutRoomSheet.show(
      context,
      roomId: roomId,
      title: d?.title ?? room.title ?? '',
      intro: d?.description ?? room.description,
      hostUserId: d?.host?.userId,
      repository: repository,
    );
    if (isClosed || result == null) return;
    if (result == TipsyBarMoreResult.deleted) {
      Navigator.of(context).pop(true);
      return;
    }
    if (result == TipsyBarMoreResult.blacklisted) {
      leaveRoomAfterBlock(context);
    }
  }

  Set<String> micSeatUserIds() {
    final ids = <String>{};
    final hostId = detail.value?.host?.userId.trim();
    if (hostId != null && hostId.isNotEmpty) ids.add(hostId);
    for (final member in detail.value?.members ?? const []) {
      if (member.isVacantSeat) continue;
      final id = member.userId.trim();
      if (id.isNotEmpty) ids.add(id);
    }
    if (joinedSeat.value) {
      final selfId = currentParticipantViewer()?.id.trim();
      if (selfId != null && selfId.isNotEmpty) ids.add(selfId);
    }
    return ids;
  }

  LiveViewer? currentParticipantViewer() {
    final profile = AuthService.cachedProfile;
    if (profile != null) {
      return LiveViewer(
        id: profile.id,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
      );
    }
    final session = ViewerSession.current;
    if (session == null) return null;
    return LiveViewer(
      id: session.id,
      displayName: session.displayName,
      avatarUrl: session.avatarUrl,
    );
  }

  void registerSelfAsVisitor() {
    if (!AuthService.isLoggedIn) return;
    final viewer = currentParticipantViewer();
    if (viewer == null) return;
    if (micSeatUserIds().contains(viewer.id)) {
      roomVisitors.remove(viewer.id);
      return;
    }
    roomVisitors[viewer.id] = viewer;
  }

  void removeSelfFromAudience() {
    final viewer = currentParticipantViewer();
    if (viewer == null) return;
    roomVisitors.remove(viewer.id);
  }

  void trackVisitorFromMessage(TipsyBarChatMessage message) {
    if (message.isSystem) return;
    final id = message.senderId?.trim();
    if (id == null || id.isEmpty) return;
    if (BlockService.isBlocked(id)) return;
    if (micSeatUserIds().contains(id)) {
      roomVisitors.remove(id);
      return;
    }
    final name = message.senderName.trim();
    if (name.isEmpty) return;
    roomVisitors[id] = LiveViewer(
      id: id,
      displayName: name,
      avatarUrl: message.avatarUrl,
    );
  }

  Future<List<LiveViewer>> buildAudienceList() async {
    final onMic = micSeatUserIds();
    final self = AuthService.isLoggedIn ? currentParticipantViewer() : null;
    final exclude = Set<String>.from(onMic);
    if (self != null) exclude.add(self.id);
    if (!AuthService.isLoggedIn) {
      final guestId = ViewerSession.current?.id.trim();
      if (guestId != null && guestId.isNotEmpty) exclude.add(guestId);
    }

    final seeds = await viewersRepo.fetchRandomViewers(
      excludeUserIds: exclude,
    );

    final merged = <String, LiveViewer>{};
    for (final viewer in seeds) {
      if (BlockService.isBlocked(viewer.id)) continue;
      if (onMic.contains(viewer.id)) continue;
      if (self != null && viewer.id == self.id) continue;
      merged[viewer.id] = viewer;
    }
    for (final visitor in roomVisitors.values) {
      if (BlockService.isBlocked(visitor.id)) continue;
      if (onMic.contains(visitor.id)) continue;
      if (exclude.contains(visitor.id)) continue;
      merged[visitor.id] = visitor;
    }

    final others = merged.values.toList(growable: false);
    if (self != null &&
        !BlockService.isBlocked(self.id) &&
        !onMic.contains(self.id)) {
      return [self, ...others.where((v) => v.id != self.id)];
    }
    return others;
  }

  Future<void> onMembersTap(BuildContext context) async {
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }
    if (isClosed) return;

    final viewers = await buildAudienceList();
    if (isClosed) return;
    await LiveViewersListSheet.show(
      context,
      streamerId: detail.value?.host?.userId,
      currentViewerId:
          AuthService.isLoggedIn ? currentParticipantViewer()?.id : null,
      viewers: viewers,
    );
  }

  Future<void> onGiftTap(BuildContext context) async {
    final coins = AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;
    final result = await LiveGiftShopSheet.show(
      context,
      initialCoinBalance: coins,
    );
    if (isClosed || result == null) return;
    await showGiftNotification(result);
  }

  String get giftSenderDisplayName {
    final auth = AuthService.cachedProfile?.displayName.trim();
    if (auth != null && auth.isNotEmpty) return auth;
    final fromNotification = giftNotificationName.value?.trim();
    if (fromNotification != null && fromNotification.isNotEmpty) {
      return fromNotification;
    }
    final viewer = ViewerSession.current?.displayName.trim();
    if (viewer != null && viewer.isNotEmpty) return viewer;
    return 'Guest';
  }

  Future<void> showGiftNotification(LiveGiftSendResult sent) async {
    final hostId = detail.value?.host?.userId.trim();
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    } else {
      await ViewerSession.ensureLoaded(
        excludeUserId: hostId?.isNotEmpty == true ? hostId : null,
      );
    }
    if (isClosed) return;

    final sender = currentParticipantViewer();
    final name = sender?.displayName.trim();
    _giftNotificationTimer?.cancel();
    giftNotificationName.value =
        (name != null && name.isNotEmpty) ? name : 'Guest';
    giftNotificationAvatarUrl.value = sender?.avatarUrl;
    giftNotificationGiftIcon.value = sent.giftIconAsset;
    _giftNotificationTimer = Timer(const Duration(seconds: 4), () {
      if (isClosed) return;
      giftNotificationName.value = null;
      giftNotificationAvatarUrl.value = null;
      giftNotificationGiftIcon.value = null;
    });
  }

}
