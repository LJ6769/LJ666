// 直播间：视频、聊天、礼物、观众列表状态。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/app_system_ui.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/foreground_media_pause.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/data/live_chat_repository.dart';
import 'package:hilmi/data/live_repository.dart';
import 'package:hilmi/data/live_viewers_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/live_chat_message.dart';
import 'package:hilmi/models/live_gift_send_result.dart';
import 'package:hilmi/models/live_stream_detail.dart';
import 'package:hilmi/models/live_viewer.dart';
import 'package:hilmi/utils/is_uuid.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/open_live_about_sheet.dart';
import 'package:hilmi/widgets/common/comment_more_sheet.dart';
import 'package:hilmi/widgets/live_room/live_gift_shop_sheet.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';
import 'package:hilmi/widgets/live_room/live_room_video_background.dart';
import 'package:hilmi/widgets/live_room/live_viewers_list_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveRoomController extends GetxController {
  LiveRoomController({
    required this.preview,
    this.initialVideoUrl,
    LiveRepository? liveRepository,
    LiveChatRepository? liveChatRepository,
  })  : liveRepository = liveRepository ?? const LiveRepository(),
        liveChatRepository = liveChatRepository ?? const LiveChatRepository();

  final LiveRoom preview;
  final String? initialVideoUrl;
  final LiveRepository liveRepository;
  final LiveChatRepository liveChatRepository;

  static const viewersRepo = LiveViewersRepository();

  final chatController = TextEditingController();
  final chatScrollController = ScrollController();
  final videoBackgroundKey = GlobalKey<LiveRoomVideoBackgroundState>();

  final knownMessageIds = <String>{};
  final messages = <LiveChatMessage>[].obs;
  final detail = Rxn<LiveStreamDetail>();
  final videoUrl = RxnString();
  final videoFailed = false.obs;
  final giftNotificationName = RxnString();
  final giftNotificationAvatarUrl = RxnString();
  final giftNotificationGiftIcon = RxnString();

  RealtimeChannel? _chatChannel;
  bool _stickChatToBottom = true;
  Timer? _giftNotificationTimer;
  List<LiveViewer>? _roomViewers;
  late final ForegroundMediaHandle _foregroundMediaHandle;

  @override
  void onInit() {
    super.onInit();
    _foregroundMediaHandle = ForegroundMediaHandle(
      pause: () async {
        await videoBackgroundKey.currentState?.pauseForOverlay();
      },
      resume: () async {
        await videoBackgroundKey.currentState?.resumeAfterOverlay();
      },
    );
    ForegroundMediaPause.register(_foregroundMediaHandle);
    final initial = initialVideoUrl?.trim() ?? '';
    final previewVideo = preview.videoUrl?.trim() ?? '';
    final resolved = initial.isNotEmpty ? initial : previewVideo;
    if (resolved.isNotEmpty) {
      videoUrl.value = resolved;
      LiveVideoPreloader.start(resolved);
    }
    chatScrollController.addListener(_onChatScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      unawaited(loadRoom());
      unawaited(initLiveChat());
    });
  }

  @override
  void onClose() {
    AppSystemUi.applyLightBackground();
    ForegroundMediaPause.unregister(_foregroundMediaHandle);
    _giftNotificationTimer?.cancel();
    _chatChannel?.unsubscribe();
    chatScrollController.removeListener(_onChatScroll);
    chatScrollController.dispose();
    chatController.dispose();
    final url = videoUrl.value?.trim();
    super.onClose();
    if (url != null && url.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LiveVideoPreloader.discard(url);
      });
    }
  }

  Future<void> stopVideoPlayback() async {
    await videoBackgroundKey.currentState?.stopPlayback();
  }

  Future<void> exitRoom(BuildContext context) async {
    await stopVideoPlayback();
    if (isClosed || !context.mounted) return;
    await Navigator.of(context).maybePop();
  }

  void _onChatScroll() {
    if (!chatScrollController.hasClients) return;
    final pos = chatScrollController.position;
    _stickChatToBottom =
        pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 24;
  }

  Future<void> initLiveChat() async {
    await loadChatHistory();
    if (isClosed) return;
    subscribeLiveChat();
  }

  Future<void> loadChatHistory() async {
    final history = await liveChatRepository.fetchMessages(preview.id);
    if (isClosed) return;

    final loaded = <LiveChatMessage>[];
    for (final msg in history) {
      if (!msg.isSystem &&
          msg.senderId != null &&
          BlockService.isBlocked(msg.senderId)) {
        continue;
      }
      final id = msg.id;
      if (id != null) {
        if (knownMessageIds.contains(id)) continue;
        knownMessageIds.add(id);
      }
      loaded.add(msg);
    }
    if (isClosed) return;
    messages.addAll(loaded);
    scheduleScrollChatToEnd(animated: false);
  }

  void subscribeLiveChat() {
    if (!AppBootstrap.isReady || AppBootstrap.client == null) return;
    if (!isUuid(preview.id)) return;

    _chatChannel?.unsubscribe();
    _chatChannel = liveChatRepository.subscribeInserts(
      liveId: preview.id,
      onInsert: onRealtimeInsert,
    );
  }

  Future<void> onRealtimeInsert(Map<String, dynamic> record) async {
    final id = record['id'] as String?;
    if (id != null && knownMessageIds.contains(id)) return;

    LiveChatMessage? message;
    if (id != null) {
      message = await liveChatRepository.fetchMessageById(id);
    }
    message ??= LiveChatMessage.fromRow(record);

    if (isClosed) return;
    appendMessage(message, scroll: true);
  }

  void appendMessage(LiveChatMessage message, {required bool scroll}) {
    if (!message.isSystem &&
        message.senderId != null &&
        BlockService.isBlocked(message.senderId)) {
      return;
    }
    final id = message.id;
    if (id != null) {
      if (knownMessageIds.contains(id)) return;
      knownMessageIds.add(id);
    }
    messages.add(message);
    if (scroll && _stickChatToBottom) {
      scheduleScrollChatToEnd();
    }
  }

  void scheduleScrollChatToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollChatToEnd(animated: animated, retryIfNotAtEnd: true);
    });
  }

  void scrollChatToEnd({
    bool animated = true,
    bool retryIfNotAtEnd = false,
  }) {
    if (isClosed || !chatScrollController.hasClients) return;

    final pos = chatScrollController.position;
    final target = pos.maxScrollExtent;
    if (animated) {
      chatScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      chatScrollController.jumpTo(target);
    }
    _stickChatToBottom = true;

    if (!retryIfNotAtEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || !chatScrollController.hasClients) return;
      final p = chatScrollController.position;
      if (p.pixels < p.maxScrollExtent - 2) {
        chatScrollController.jumpTo(p.maxScrollExtent);
      }
    });
  }

  Future<void> loadRoom() async {
    final loaded = await liveRepository.fetchRoomDetail(
      preview.id,
      includeCover: false,
    );
    if (isClosed) return;

    final resolvedVideo = loaded?.videoUrl?.trim() ?? '';
    final nextUrl = resolvedVideo.isNotEmpty
        ? resolvedVideo
        : (videoUrl.value?.isNotEmpty == true ? videoUrl.value : null);

    if (nextUrl != null &&
        nextUrl.isNotEmpty &&
        nextUrl != videoUrl.value?.trim()) {
      LiveVideoPreloader.discard(videoUrl.value);
      LiveVideoPreloader.start(nextUrl);
    }

    detail.value = loaded;
    if (nextUrl?.isNotEmpty == true) {
      videoUrl.value = nextUrl;
    }
    videoFailed.value = false;
    unawaited(
      ViewerSession.ensureLoaded(
        excludeUserId: loaded?.streamerId ?? preview.hostId,
      ),
    );
    unawaited(ensureRoomViewersLoaded());
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

  Future<void> ensureRoomViewersLoaded() async {
    if (_roomViewers != null) return;

    final streamerId = (detail.value?.streamerId ?? preview.hostId)?.trim();
    final exclude = <String>{};
    if (streamerId != null && streamerId.isNotEmpty) exclude.add(streamerId);

    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }

    final self = AuthService.isLoggedIn ? currentParticipantViewer() : null;
    if (self != null) exclude.add(self.id);
    if (!AuthService.isLoggedIn) {
      final guestId = ViewerSession.current?.id.trim();
      if (guestId != null && guestId.isNotEmpty) exclude.add(guestId);
    }

    final list = await viewersRepo.fetchRandomViewers(
      excludeUserIds: exclude,
    );
    if (isClosed) return;

    final seeds = list
        .where((v) => !BlockService.isBlocked(v.id))
        .where((v) => self == null || v.id != self.id)
        .toList(growable: false);

    if (self != null && !BlockService.isBlocked(self.id)) {
      _roomViewers = [self, ...seeds];
    } else {
      _roomViewers = seeds;
    }
  }

  String get hostName =>
      detail.value?.streamerName ?? preview.hostName ?? 'Host';

  String get hostHandle {
    final d = detail.value;
    if (d != null) return d.streamerHandle;
    return preview.displayHostHandle;
  }

  String? get avatarUrl =>
      detail.value?.streamerAvatarUrl ?? preview.hostAvatarUrl;

  bool get hasVideoUrl =>
      videoUrl.value != null && videoUrl.value!.trim().isNotEmpty;

  static String get communityNoticeText =>
      'Tips: ${LiveRoomAssets.tipsMessage}';

  Future<void> openAboutSheet(BuildContext context) async {
    final d = detail.value;
    if (d == null) return;

    final blacklisted = await openLiveAboutSheetFromDetail(
      context,
      d,
      streamerId: d.streamerId ?? preview.hostId,
    );
    if (blacklisted && !isClosed) {
      Navigator.of(context).pop();
    }
  }

  Future<void> onMoreTap(BuildContext context) => openAboutSheet(context);

  Future<void> onAboutTap(BuildContext context) => openAboutSheet(context);

  Future<bool> deleteOwnChatMessage(LiveChatMessage message) async {
    final id = message.id?.trim();
    if (id == null || id.isEmpty) return false;
    if (AuthService.isLoggedIn) {
      return liveChatRepository.deleteMessage(id);
    }
    return message.isOwn;
  }

  Future<void> onChatMessageTap(
    BuildContext context,
    LiveChatMessage message,
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
      messages.removeWhere((m) => m.id != null && m.id == message.id);
      return;
    }
    if (result == CommentMoreResult.blacklisted) {
      messages.removeWhere(
        (m) => m.senderId != null && BlockService.isBlocked(m.senderId),
      );
    }
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

  Future<void> onViewersTap(BuildContext context) async {
    await ensureRoomViewersLoaded();
    if (isClosed) return;
    await LiveViewersListSheet.show(
      context,
      streamerId: detail.value?.streamerId ?? preview.hostId,
      currentViewerId:
          AuthService.isLoggedIn ? currentParticipantViewer()?.id : null,
      viewers: _roomViewers ?? const [],
    );
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
    final streamerId = detail.value?.streamerId ?? preview.hostId;
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    } else {
      await ViewerSession.ensureLoaded(
        excludeUserId:
            streamerId?.trim().isNotEmpty == true ? streamerId : null,
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

  String localChatSenderDisplayName() {
    final auth = AuthService.cachedProfile?.displayName.trim();
    if (auth != null && auth.isNotEmpty) return auth;
    final viewer = ViewerSession.current?.displayName.trim();
    if (viewer != null && viewer.isNotEmpty) return viewer;
    return 'Guest';
  }

  String? localChatSenderAvatarUrl() {
    final auth = AuthService.cachedProfile?.avatarUrl?.trim();
    if (auth != null && auth.isNotEmpty) return auth;
    return ViewerSession.current?.avatarUrl;
  }

  Future<void> onSendChat(BuildContext context) async {
    final text = chatController.text.trim();
    if (text.isEmpty) return;

    if (!await ensureLoggedIn(
      context,
      loginHint: 'Please sign in to send messages',
    )) {
      return;
    }
    if (isClosed) return;

    try {
      final message = await liveChatRepository.sendMessage(
        liveId: preview.id,
        content: text,
      );
      if (isClosed) return;
      chatController.clear();
      appendMessage(_copyAsOwn(message), scroll: true);
    } catch (error) {
      debugPrint('[LiveRoomController] send chat: $error');
      if (isClosed) return;
      final local = LiveChatMessage(
        text: text,
        userName: localChatSenderDisplayName(),
        avatarUrl: localChatSenderAvatarUrl(),
        isOwn: true,
      );
      chatController.clear();
      appendMessage(local, scroll: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message shown locally. Sync failed — check your network or database policies.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void onVideoReady() {
    if (isClosed) return;
    videoFailed.value = false;
  }

  void onVideoFailed() {
    if (isClosed) return;
    videoFailed.value = true;
  }

  void onPopInvoked() {
    AppSystemUi.applyLightBackground();
    unawaited(stopVideoPlayback());
  }

  LiveChatMessage _copyAsOwn(LiveChatMessage message) => LiveChatMessage(
        id: message.id,
        senderId: message.senderId,
        text: message.text,
        userName: message.userName,
        avatarUrl: message.avatarUrl,
        isSystem: message.isSystem,
        isOwn: true,
        createdAt: message.createdAt,
      );
}
