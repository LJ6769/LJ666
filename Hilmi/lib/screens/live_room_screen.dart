import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/foreground_media_pause.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/utils/is_uuid.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/live_room_about_tags.dart';
import 'package:hilmi/data/live_chat_repository.dart';
import 'package:hilmi/data/live_repository.dart';
import 'package:hilmi/data/live_viewers_repository.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/live_chat_message.dart';
import 'package:hilmi/models/live_viewer.dart';
import 'package:hilmi/models/live_gift_send_result.dart';
import 'package:hilmi/models/live_stream_detail.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';
import 'package:hilmi/widgets/live_room/live_about_sheet.dart';
import 'package:hilmi/widgets/live_room/live_gift_notification_banner.dart';
import 'package:hilmi/widgets/live_room/live_gift_shop_sheet.dart';
import 'package:hilmi/widgets/live_room/live_viewers_list_sheet.dart';
import 'package:hilmi/widgets/live_room/live_room_bottom_bar.dart';
import 'package:hilmi/widgets/live_room/live_room_chat_panel.dart';
import 'package:hilmi/widgets/live_room/live_room_top_bar.dart';
import 'package:hilmi/widgets/live_room/live_room_video_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 直播间：全屏视频 + 可下滑聊天区 + 底部输入（布局对齐 Tjgo）。
class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({
    super.key,
    required this.preview,
    this.initialVideoUrl,
    this.liveRepository = const LiveRepository(),
    this.liveChatRepository = const LiveChatRepository(),
  });

  final LiveRoom preview;
  final String? initialVideoUrl;
  final LiveRepository liveRepository;
  final LiveChatRepository liveChatRepository;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  static const _designWidth = 375.0;
  static const _videoAlignment = Alignment(0, -0.18);
  static const _chatOverlayTopFraction = 0.62;
  static const _inputBarHeight = 48.0;
  static const _chatGapAboveInput = 8.0;

  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _videoBackgroundKey = GlobalKey<LiveRoomVideoBackgroundState>();
  final _knownMessageIds = <String>{};
  final _messages = <LiveChatMessage>[];

  RealtimeChannel? _chatChannel;
  LiveStreamDetail? _detail;
  String? _videoUrl;
  bool _videoFailed = false;
  bool _stickChatToBottom = true;
  Timer? _giftNotificationTimer;
  String? _giftNotificationName;
  String? _giftNotificationAvatarUrl;
  String? _giftNotificationGiftIcon;

  static const _viewersRepo = LiveViewersRepository();

  /// 进房后抽取一次，同一直播间内重复打开观众列表不再刷新。
  List<LiveViewer>? _roomViewers;

  late final ForegroundMediaHandle _foregroundMediaHandle = ForegroundMediaHandle(
    pause: () async {
      await _videoBackgroundKey.currentState?.pauseForOverlay();
    },
    resume: () async {
      await _videoBackgroundKey.currentState?.resumeAfterOverlay();
    },
  );

  @override
  void initState() {
    super.initState();
    ForegroundMediaPause.register(_foregroundMediaHandle);
    final initial = widget.initialVideoUrl?.trim() ?? '';
    final previewVideo = widget.preview.videoUrl?.trim() ?? '';
    _videoUrl = initial.isNotEmpty ? initial : previewVideo;
    if (_videoUrl != null && _videoUrl!.isNotEmpty) {
      LiveVideoPreloader.start(_videoUrl);
    }
    _chatScrollController.addListener(_onChatScroll);
    _loadRoom();
    _initLiveChat();
    unawaited(_loadViewerProfile());
  }

  Future<void> _loadViewerProfile() async {
    await ViewerSession.ensureLoaded(
      excludeUserId: _detail?.streamerId ?? widget.preview.hostId,
    );
  }

  @override
  void dispose() {
    ForegroundMediaPause.unregister(_foregroundMediaHandle);
    _giftNotificationTimer?.cancel();
    _chatChannel?.unsubscribe();
    _chatScrollController.removeListener(_onChatScroll);
    _chatScrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _onChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final pos = _chatScrollController.position;
    _stickChatToBottom =
        pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 24;
  }

  Future<void> _initLiveChat() async {
    await _loadChatHistory();
    if (!mounted) return;
    _subscribeLiveChat();
  }

  Future<void> _loadChatHistory() async {
    final history = await widget.liveChatRepository.fetchMessages(
      widget.preview.id,
    );
    if (!mounted) return;

    final loaded = <LiveChatMessage>[];
    for (final msg in history) {
      if (!msg.isSystem &&
          msg.senderId != null &&
          BlockService.isBlocked(msg.senderId)) {
        continue;
      }
      final id = msg.id;
      if (id != null) {
        if (_knownMessageIds.contains(id)) continue;
        _knownMessageIds.add(id);
      }
      loaded.add(msg);
    }
    if (!mounted) return;
    setState(() => _messages.addAll(loaded));
    _scheduleScrollChatToEnd(animated: false);
  }

  void _subscribeLiveChat() {
    if (!AppBootstrap.isReady || AppBootstrap.client == null) return;
    if (!isUuid(widget.preview.id)) return;

    _chatChannel?.unsubscribe();
    _chatChannel = widget.liveChatRepository.subscribeInserts(
      liveId: widget.preview.id,
      onInsert: _onRealtimeInsert,
    );
  }

  Future<void> _onRealtimeInsert(Map<String, dynamic> record) async {
    final id = record['id'] as String?;
    if (id != null && _knownMessageIds.contains(id)) return;

    LiveChatMessage? message;
    if (id != null) {
      message = await widget.liveChatRepository.fetchMessageById(id);
    }
    message ??= LiveChatMessage.fromRow(record);

    if (!mounted) return;
    setState(() => _appendMessage(message!, scroll: true));
  }

  void _appendMessage(LiveChatMessage message, {required bool scroll}) {
    if (!message.isSystem &&
        message.senderId != null &&
        BlockService.isBlocked(message.senderId)) {
      return;
    }
    final id = message.id;
    if (id != null) {
      if (_knownMessageIds.contains(id)) return;
      _knownMessageIds.add(id);
    }
    _messages.add(message);
    if (scroll && _stickChatToBottom) {
      _scheduleScrollChatToEnd();
    }
  }

  void _scheduleScrollChatToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollChatToEnd(animated: animated, retryIfNotAtEnd: true);
    });
  }

  void _scrollChatToEnd({
    bool animated = true,
    bool retryIfNotAtEnd = false,
  }) {
    if (!mounted || !_chatScrollController.hasClients) return;

    final pos = _chatScrollController.position;
    final target = pos.maxScrollExtent;
    if (animated) {
      _chatScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _chatScrollController.jumpTo(target);
    }
    _stickChatToBottom = true;

    if (!retryIfNotAtEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      final p = _chatScrollController.position;
      if (p.pixels < p.maxScrollExtent - 2) {
        _chatScrollController.jumpTo(p.maxScrollExtent);
      }
    });
  }

  Future<void> _loadRoom() async {
    final detail = await widget.liveRepository.fetchRoomDetail(
      widget.preview.id,
    );
    if (!mounted) return;

    final resolvedVideo = detail?.videoUrl?.trim() ?? '';
    final videoUrl = resolvedVideo.isNotEmpty
        ? resolvedVideo
        : (_videoUrl?.isNotEmpty == true ? _videoUrl : null);

    if (videoUrl != null &&
        videoUrl.isNotEmpty &&
        videoUrl != _videoUrl?.trim()) {
      LiveVideoPreloader.discard(_videoUrl);
      LiveVideoPreloader.start(videoUrl);
    }

    setState(() {
      _detail = detail;
      _videoUrl = videoUrl?.isNotEmpty == true ? videoUrl : _videoUrl;
      _videoFailed = false;
    });
    unawaited(
      ViewerSession.ensureLoaded(
        excludeUserId: detail?.streamerId ?? widget.preview.hostId,
      ),
    );
    unawaited(_ensureRoomViewersLoaded());
  }

  LiveViewer? _currentParticipantViewer() {
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

  Future<void> _ensureRoomViewersLoaded() async {
    if (_roomViewers != null) return;

    final streamerId = (_detail?.streamerId ?? widget.preview.hostId)?.trim();
    final exclude = <String>{};
    if (streamerId != null && streamerId.isNotEmpty) exclude.add(streamerId);

    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }

    final self = AuthService.isLoggedIn ? _currentParticipantViewer() : null;
    if (self != null) exclude.add(self.id);
    if (!AuthService.isLoggedIn) {
      final guestId = ViewerSession.current?.id.trim();
      if (guestId != null && guestId.isNotEmpty) exclude.add(guestId);
    }

    final list = await _viewersRepo.fetchRandomViewers(
      minCount: 5,
      maxCount: 12,
      excludeUserIds: exclude,
    );
    if (!mounted) return;

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

  String? get _coverUrl => _detail?.coverUrl ?? widget.preview.coverUrl;

  String get _hostName =>
      _detail?.streamerName ?? widget.preview.hostName ?? 'Host';

  String get _hostHandle {
    if (_detail != null) return _detail!.streamerHandle;
    return widget.preview.displayHostHandle;
  }

  String? get _avatarUrl =>
      _detail?.streamerAvatarUrl ?? widget.preview.hostAvatarUrl;

  bool get _hasVideoUrl => _videoUrl != null && _videoUrl!.trim().isNotEmpty;

  static String get _communityNoticeText =>
      'Tips: ${LiveRoomAssets.tipsMessage}';

  double _scale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / _designWidth).clamp(0.85, 1.15);
  }

  Future<void> _openAboutSheet() async {
    final detail = _detail;
    final displayTags = LiveRoomAboutTags.build(
      categorySlug: detail?.categorySlug,
      categoryName: detail?.categoryName,
      tags: detail?.tags ?? const [],
    );

    final blacklisted = await LiveAboutSheet.show(
      context,
      description: detail?.description,
      tags: displayTags,
      streamerId: detail?.streamerId ?? widget.preview.hostId,
    );
    if (blacklisted && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onMoreTap() => _openAboutSheet();

  Future<void> _onAboutTap() => _openAboutSheet();

  Future<void> _onGiftTap() async {
    final coins = AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;
    final result = await LiveGiftShopSheet.show(
      context,
      initialCoinBalance: coins,
    );
    if (!mounted || result == null) return;
    await _showGiftNotification(result);
  }

  Future<void> _onViewersTap() async {
    await _ensureRoomViewersLoaded();
    if (!mounted) return;
    await LiveViewersListSheet.show(
      context,
      streamerId: _detail?.streamerId ?? widget.preview.hostId,
      currentViewerId: AuthService.isLoggedIn
          ? _currentParticipantViewer()?.id
          : null,
      viewers: _roomViewers ?? const [],
    );
  }

  String get _giftSenderDisplayName {
    final auth = AuthService.cachedProfile?.displayName.trim();
    if (auth != null && auth.isNotEmpty) return auth;
    final fromNotification = _giftNotificationName?.trim();
    if (fromNotification != null && fromNotification.isNotEmpty) {
      return fromNotification;
    }
    final viewer = ViewerSession.current?.displayName.trim();
    if (viewer != null && viewer.isNotEmpty) return viewer;
    return 'Guest';
  }

  Future<void> _showGiftNotification(LiveGiftSendResult sent) async {
    final streamerId = _detail?.streamerId ?? widget.preview.hostId;
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    } else {
      await ViewerSession.ensureLoaded(
        excludeUserId: streamerId?.trim().isNotEmpty == true ? streamerId : null,
      );
    }
    if (!mounted) return;

    final sender = _currentParticipantViewer();
    final name = sender?.displayName.trim();
    _giftNotificationTimer?.cancel();
    setState(() {
      _giftNotificationName =
          (name != null && name.isNotEmpty) ? name : 'Guest';
      _giftNotificationAvatarUrl = sender?.avatarUrl;
      _giftNotificationGiftIcon = sent.giftIconAsset;
    });
    _giftNotificationTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _giftNotificationName = null;
        _giftNotificationAvatarUrl = null;
        _giftNotificationGiftIcon = null;
      });
    });
  }

  String _localChatSenderDisplayName() {
    final auth = AuthService.cachedProfile?.displayName.trim();
    if (auth != null && auth.isNotEmpty) return auth;
    final viewer = ViewerSession.current?.displayName.trim();
    if (viewer != null && viewer.isNotEmpty) return viewer;
    return 'Guest';
  }

  String? _localChatSenderAvatarUrl() {
    final auth = AuthService.cachedProfile?.avatarUrl?.trim();
    if (auth != null && auth.isNotEmpty) return auth;
    return ViewerSession.current?.avatarUrl;
  }

  Future<void> _onSendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to send messages')) {
      return;
    }
    if (!mounted) return;

    try {
      final message = await widget.liveChatRepository.sendMessage(
        liveId: widget.preview.id,
        content: text,
      );
      if (!mounted) return;
      _chatController.clear();
      setState(() => _appendMessage(message.copyAsOwn(), scroll: true));
    } catch (error) {
      debugPrint('[LiveRoomScreen] send chat: $error');
      if (!mounted) return;
      final local = LiveChatMessage(
        text: text,
        userName: _localChatSenderDisplayName(),
        avatarUrl: _localChatSenderAvatarUrl(),
        isOwn: true,
      );
      _chatController.clear();
      setState(() => _appendMessage(local, scroll: true));
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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    final scale = _scale(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final isChatInputActive = keyboardHeight > 0;
    final screenSize = MediaQuery.sizeOf(context);
    final bottomInset = keyboardHeight +
        (isChatInputActive ? 8 * scale : bottomPad + 8 * scale);
    final chatAreaBottom =
        bottomInset + _inputBarHeight + _chatGapAboveInput * scale;
    final chatOverlayTop = screenSize.height * _chatOverlayTopFraction;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasVideoUrl)
            LiveRoomVideoBackground(
              key: _videoBackgroundKey,
              videoUrl: _videoUrl,
              alignment: _videoAlignment,
              onVideoReady: () {
                if (!mounted) return;
                setState(() => _videoFailed = false);
              },
              onVideoFailed: () {
                if (!mounted) return;
                setState(() => _videoFailed = true);
              },
            )
          else
            _CoverLayer(coverUrl: _coverUrl),
          if (_hasVideoUrl && _videoFailed) ...[
            _CoverLayer(coverUrl: _coverUrl),
            const _VideoUnavailableHint(),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0, 0.22, 0.55, 1],
              ),
            ),
          ),
          if (_giftNotificationGiftIcon != null)
            Positioned(
              left: 12 * scale,
              top: (screenSize.height -
                      LiveGiftNotificationBanner.designHeight * scale) /
                  2,
              child: LiveGiftNotificationBanner(
                scale: scale,
                displayName: _giftSenderDisplayName,
                avatarUrl: _giftNotificationAvatarUrl,
                giftIconAsset: _giftNotificationGiftIcon!,
              ),
            ),
          SafeArea(
            bottom: false,
            child: LiveRoomTopBar(
              hostName: _hostName,
              hostHandle: _hostHandle,
              avatarUrl: _avatarUrl,
              streamerEmail: _detail?.streamerEmail,
              streamerId: _detail?.streamerId ?? widget.preview.hostId,
              onBack: () => Navigator.of(context).maybePop(),
              onAboutTap: _onAboutTap,
              onAvatarTap: () {
                final id = (_detail?.streamerId ?? widget.preview.hostId)
                    ?.trim();
                if (id == null || id.isEmpty) return;
                openStarProfileForUser(
                  context,
                  userId: id,
                  name: _hostName,
                  email: _detail?.streamerEmail ?? widget.preview.hostEmail,
                  imageUrl: _avatarUrl,
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: chatOverlayTop,
            bottom: chatAreaBottom,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              child: LiveRoomChatPanel(
                scale: scale,
                messages: _messages,
                scrollController: _chatScrollController,
                communityNoticeText: _communityNoticeText,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: LiveRoomBottomBar(
                chatController: _chatController,
                onSend: _onSendChat,
                onGift: _onGiftTap,
                onViewers: _onViewersTap,
                onMore: _onMoreTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on LiveChatMessage {
  LiveChatMessage copyAsOwn() => LiveChatMessage(
        id: id,
        senderId: senderId,
        text: text,
        userName: userName,
        avatarUrl: avatarUrl,
        isSystem: isSystem,
        isOwn: true,
        createdAt: createdAt,
      );
}

class _VideoUnavailableHint extends StatelessWidget {
  const _VideoUnavailableHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Video unavailable.\nMake sure live-streams/.../video.mp4 is uploaded to Storage.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _CoverLayer extends StatelessWidget {
  const _CoverLayer({this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl?.trim() ?? '';
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF1A1035),
        child: Center(
          child: Icon(Icons.videocam_outlined, color: Colors.white24, size: 56),
        ),
      );
    }
    return CachedMediaImage(
      url: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
