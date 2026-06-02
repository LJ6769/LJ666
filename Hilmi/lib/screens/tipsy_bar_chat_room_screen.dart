import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/viewer_session.dart';
import 'package:hilmi/data/live_viewers_repository.dart';
import 'package:hilmi/data/tipsy_bar_chat_repository.dart';
import 'package:hilmi/models/live_viewer.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/models/live_gift_send_result.dart';
import 'package:hilmi/models/tipsy_bar_chat.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/follow/follow_action_button.dart';
import 'package:hilmi/widgets/host_info_bar.dart';
import 'package:hilmi/core/foreground_media_pause.dart';
import 'package:hilmi/services/tipsy_bar_host_audio_player.dart';
import 'package:hilmi/widgets/live_room/live_gift_notification_banner.dart';
import 'package:hilmi/widgets/live_room/live_gift_shop_sheet.dart';
import 'package:hilmi/widgets/live_room/live_viewers_list_sheet.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_about_room_sheet.dart';
import 'package:hilmi/widgets/tipsy_bar/tipsy_bar_chat_assets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tipsy Bar 语音聊天室（点击卡片 Join in 进入）。
class TipsyBarChatRoomScreen extends StatefulWidget {
  const TipsyBarChatRoomScreen({
    super.key,
    required this.room,
    this.repository = const TipsyBarChatRepository(),
    this.openAboutRoomOnEnter = false,
  });

  final TipsyBarRoom room;
  final TipsyBarChatRepository repository;
  final bool openAboutRoomOnEnter;

  static const _designWidth = 375.0;
  static const _pageBackground = Color(0xFFFEFAEF);

  /// 礼物横幅相对屏幕垂直居中再上移（直播间仍用正中）。
  static const _giftBannerUpOffset = 80.0;

  @override
  State<TipsyBarChatRoomScreen> createState() => _TipsyBarChatRoomScreenState();
}

class _TipsyBarChatRoomScreenState extends State<TipsyBarChatRoomScreen> {
  TipsyBarChatRoomDetail? _detail;
  List<TipsyBarChatMessage> _messages = [];
  bool _loading = true;
  bool _soundOn = true;
  bool _joinedSeat = false;
  bool _micOn = true;
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final _hostAudio = TipsyBarHostAudioPlayer();
  bool _pendingAboutRoom = false;
  bool _resumeHostAudioAfterOverlay = false;

  late final ForegroundMediaHandle _foregroundMediaHandle = ForegroundMediaHandle(
    pause: () async {
      if (!_soundOn) return;
      _resumeHostAudioAfterOverlay = true;
      await _hostAudio.pause();
    },
    resume: () async {
      if (!_resumeHostAudioAfterOverlay || !_soundOn || !mounted) {
        _resumeHostAudioAfterOverlay = false;
        return;
      }
      _resumeHostAudioAfterOverlay = false;
      await _playHostAudio(
        _detail?.hostAudioUrl,
        cacheKey: _detail?.hostAudioPath,
      );
    },
  );
  final _knownMessageIds = <String>{};
  RealtimeChannel? _chatChannel;
  Timer? _giftNotificationTimer;
  String? _giftNotificationName;
  String? _giftNotificationAvatarUrl;
  String? _giftNotificationGiftIcon;

  static const _viewersRepo = LiveViewersRepository();

  /// 已进入房间、未上麦的观众（含当前用户与其它发言用户）。
  final Map<String, LiveViewer> _roomVisitors = {};

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / TipsyBarChatRoomScreen._designWidth;

  String? get _currentUserId {
    final profileId = AuthService.cachedProfile?.id.trim();
    if (profileId != null && profileId.isNotEmpty) return profileId;
    final viewerId = ViewerSession.current?.id.trim();
    if (viewerId != null && viewerId.isNotEmpty) return viewerId;
    return null;
  }

  /// 当前用户是否为该房房主（创建者已在麦位 0，不可再 Join in）。
  bool get _isRoomHost {
    final hostId = _detail?.host?.userId.trim() ?? '';
    final selfId = _currentUserId ?? '';
    return hostId.isNotEmpty && selfId.isNotEmpty && hostId == selfId;
  }

  @override
  void initState() {
    super.initState();
    ForegroundMediaPause.register(_foregroundMediaHandle);
    _pendingAboutRoom = widget.openAboutRoomOnEnter;
    _load();
  }

  @override
  void dispose() {
    ForegroundMediaPause.unregister(_foregroundMediaHandle);
    _giftNotificationTimer?.cancel();
    _chatChannel?.unsubscribe();
    _hostAudio.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await widget.repository.fetchRoomDetail(widget.room.id);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
    if (detail != null) {
      await _initRoomChat(detail.id);
      await _loadViewerProfile();
      _registerSelfAsVisitor();
    } else {
      setState(() => _messages = [widget.repository.communityTips()]);
    }
    if (!mounted) return;
    if (_soundOn) {
      await _playHostAudio(
        detail?.hostAudioUrl,
        cacheKey: detail?.hostAudioPath,
      );
    }
    if (_pendingAboutRoom) {
      _pendingAboutRoom = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_onMoreTap());
      });
    }
  }

  Future<void> _initRoomChat(String roomId) async {
    await _loadChatHistory(roomId);
    if (!mounted) return;
    _subscribeRoomChat(roomId);
  }

  Future<void> _loadChatHistory(String roomId) async {
    final history = await widget.repository.fetchMessages(roomId);
    if (!mounted) return;

    final loaded = <TipsyBarChatMessage>[widget.repository.communityTips()];
    for (final msg in history) {
      if (msg.senderId != null && BlockService.isBlocked(msg.senderId)) {
        continue;
      }
      final id = msg.id;
      if (id.isNotEmpty) {
        if (_knownMessageIds.contains(id)) continue;
        _knownMessageIds.add(id);
      }
      loaded.add(msg);
      _trackVisitorFromMessage(msg);
    }

    setState(() => _messages = loaded);
    _scrollChatToEnd();
  }

  void _subscribeRoomChat(String roomId) {
    if (!AppBootstrap.isReady || AppBootstrap.client == null) return;

    _chatChannel?.unsubscribe();
    _chatChannel = widget.repository.subscribeInserts(
      roomId: roomId,
      onInsert: _onRealtimeInsert,
    );
  }

  Future<void> _onRealtimeInsert(Map<String, dynamic> record) async {
    final id = record['id'] as String?;
    if (id != null && _knownMessageIds.contains(id)) return;

    TipsyBarChatMessage? message;
    if (id != null) {
      message = await widget.repository.fetchMessageById(id);
    }
    message ??= TipsyBarChatMessage.fromRow(
      record,
      currentUserId: AuthService.cachedProfile?.id,
    );

    if (!mounted) return;
    _appendMessage(message);
  }

  void _appendMessage(TipsyBarChatMessage message) {
    if (message.senderId != null && BlockService.isBlocked(message.senderId)) {
      return;
    }
    final id = message.id;
    if (id.isNotEmpty) {
      if (_knownMessageIds.contains(id)) return;
      _knownMessageIds.add(id);
    }
    _trackVisitorFromMessage(message);
    setState(() => _messages = [..._messages, message]);
    _scrollChatToEnd();
  }

  Future<void> _playHostAudio(String? url, {String? cacheKey}) async {
    if (!mounted || url == null || url.trim().isEmpty) return;
    await _hostAudio.playUrl(url, cacheKey: cacheKey);
  }

  Future<void> _onSoundTap() async {
    final next = !_soundOn;
    setState(() => _soundOn = next);
    if (next) {
      await _playHostAudio(
        _detail?.hostAudioUrl,
        cacheKey: _detail?.hostAudioPath,
      );
    } else {
      await _hostAudio.pause();
    }
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _onSend() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to send messages')) {
      return;
    }
    if (!mounted) return;

    final roomId = _detail?.id ?? widget.room.id;
    _chatController.clear();

    try {
      final message = await widget.repository.sendMessage(
        roomId: roomId,
        content: text,
      );
      if (!mounted) return;
      _appendMessage(message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onJoinSeat() async {
    if (_isRoomHost) return;

    if (!AuthService.isLoggedIn) {
      final loggedIn = await openLoginScreen(context);
      if (!mounted || loggedIn != true) return;
      await AuthService.loadCurrentProfile(forceRefresh: true);
    }
    if (!mounted) return;
    setState(() {
      _joinedSeat = true;
      _micOn = true;
      _removeSelfFromAudience();
    });
  }

  void _onLeaveSeat() {
    setState(() {
      _joinedSeat = false;
      _micOn = true;
      _registerSelfAsVisitor();
    });
  }

  void _onMicTap() {
    if (!_joinedSeat) return;
    setState(() => _micOn = !_micOn);
  }

  Future<void> _loadViewerProfile() async {
    if (!AuthService.isLoggedIn) return;
    await AuthService.loadCurrentProfile();
  }

  Future<void> _onMoreTap() async {
    final detail = _detail;
    final roomId = detail?.id ?? widget.room.id;
    final result = await TipsyBarAboutRoomSheet.show(
      context,
      roomId: roomId,
      title: detail?.title ?? widget.room.title ?? '',
      intro: detail?.description ?? widget.room.description,
      hostUserId: detail?.host?.userId,
      repository: widget.repository,
    );
    if (!mounted || result == null) return;
    if (result == TipsyBarMoreResult.deleted) {
      Navigator.of(context).pop(true);
      return;
    }
    if (result == TipsyBarMoreResult.blacklisted) {
      Navigator.of(context).pop();
    }
  }

  Set<String> _micSeatUserIds() {
    final ids = <String>{};
    final hostId = _detail?.host?.userId.trim();
    if (hostId != null && hostId.isNotEmpty) ids.add(hostId);
    for (final member in _detail?.members ?? const []) {
      if (member.isVacantSeat) continue;
      final id = member.userId.trim();
      if (id.isNotEmpty) ids.add(id);
    }
    if (_joinedSeat) {
      final selfId = _currentParticipantViewer()?.id.trim();
      if (selfId != null && selfId.isNotEmpty) ids.add(selfId);
    }
    return ids;
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

  void _registerSelfAsVisitor() {
    if (!AuthService.isLoggedIn) return;
    final viewer = _currentParticipantViewer();
    if (viewer == null) return;
    if (_micSeatUserIds().contains(viewer.id)) {
      _roomVisitors.remove(viewer.id);
      return;
    }
    _roomVisitors[viewer.id] = viewer;
  }

  void _removeSelfFromAudience() {
    final viewer = _currentParticipantViewer();
    if (viewer == null) return;
    _roomVisitors.remove(viewer.id);
  }

  void _trackVisitorFromMessage(TipsyBarChatMessage message) {
    if (message.isSystem) return;
    final id = message.senderId?.trim();
    if (id == null || id.isEmpty) return;
    if (BlockService.isBlocked(id)) return;
    if (_micSeatUserIds().contains(id)) {
      _roomVisitors.remove(id);
      return;
    }
    final name = message.senderName.trim();
    if (name.isEmpty) return;
    _roomVisitors[id] = LiveViewer(
      id: id,
      displayName: name,
      avatarUrl: message.avatarUrl,
    );
  }

  Future<List<LiveViewer>> _buildAudienceList() async {
    final onMic = _micSeatUserIds();
    final self = AuthService.isLoggedIn ? _currentParticipantViewer() : null;
    final exclude = Set<String>.from(onMic);
    if (self != null) exclude.add(self.id);
    if (!AuthService.isLoggedIn) {
      final guestId = ViewerSession.current?.id.trim();
      if (guestId != null && guestId.isNotEmpty) exclude.add(guestId);
    }

    final seeds = await _viewersRepo.fetchRandomViewers(
      minCount: 5,
      maxCount: 8,
      excludeUserIds: exclude,
    );

    final merged = <String, LiveViewer>{};
    for (final viewer in seeds) {
      if (BlockService.isBlocked(viewer.id)) continue;
      if (onMic.contains(viewer.id)) continue;
      if (self != null && viewer.id == self.id) continue;
      merged[viewer.id] = viewer;
    }
    for (final visitor in _roomVisitors.values) {
      if (BlockService.isBlocked(visitor.id)) continue;
      if (onMic.contains(visitor.id)) continue;
      if (exclude.contains(visitor.id)) continue;
      merged[visitor.id] = visitor;
    }

    final others = merged.values.toList(growable: false);
    if (self != null && !BlockService.isBlocked(self.id) && !onMic.contains(self.id)) {
      return [self, ...others.where((v) => v.id != self.id)];
    }
    return others;
  }

  Future<void> _onMembersTap() async {
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    }
    if (!mounted) return;

    final viewers = await _buildAudienceList();
    if (!mounted) return;
    await LiveViewersListSheet.show(
      context,
      streamerId: _detail?.host?.userId,
      currentViewerId: AuthService.isLoggedIn
          ? _currentParticipantViewer()?.id
          : null,
      viewers: viewers,
    );
  }

  Future<void> _onGiftTap() async {
    final coins = AuthService.cachedProfile?.coins ?? UserConfig.guestBalance;
    final result = await LiveGiftShopSheet.show(
      context,
      initialCoinBalance: coins,
    );
    if (!mounted || result == null) return;
    await _showGiftNotification(result);
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
    final hostId = _detail?.host?.userId.trim();
    if (AuthService.isLoggedIn) {
      await AuthService.loadCurrentProfile();
    } else {
      await ViewerSession.ensureLoaded(
        excludeUserId: hostId?.isNotEmpty == true ? hostId : null,
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

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final detail = _detail;
    final host = detail?.host;
    final screenSize = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: TipsyBarChatRoomScreen._pageBackground,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD14D4D),
                  strokeWidth: 2,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      TipsyBarChatAssets.bg,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  if (_giftNotificationGiftIcon != null)
                    Positioned(
                      left: 12 * s,
                      top: (screenSize.height -
                                  LiveGiftNotificationBanner.designHeight * s) /
                              2 -
                          TipsyBarChatRoomScreen._giftBannerUpOffset * s,
                      child: LiveGiftNotificationBanner(
                        scale: s,
                        displayName: _giftSenderDisplayName,
                        avatarUrl: _giftNotificationAvatarUrl,
                        giftIconAsset: _giftNotificationGiftIcon!,
                      ),
                    ),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TipsyBarChatTopBar(
                          scale: s,
                          topInset: topInset,
                          host: host,
                          joinedSeat: _joinedSeat,
                          micOn: _micOn,
                          soundOn: _soundOn,
                          onBack: () => Navigator.of(context).pop(),
                          onMicTap: _onMicTap,
                          onSoundTap: _onSoundTap,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 8 * s, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _TipsyBarChatMessageList(
                                    scale: s,
                                    messages: _messages,
                                    scrollController: _chatScrollController,
                                  ),
                                ),
                                SizedBox(width: 8 * s),
                                _TipsyBarSeatsColumn(
                                  scale: s,
                                  detail: detail,
                                  joinedSeat: _joinedSeat,
                                  isRoomHost: _isRoomHost,
                                  micOn: _micOn,
                                  soundOn: _soundOn,
                                  onJoinTap: _onJoinSeat,
                                  onLeaveSeat: _onLeaveSeat,
                                ),
                              ],
                            ),
                          ),
                        ),
                        _TipsyBarChatBottomBar(
                          scale: s,
                          bottomInset: bottomInset,
                          controller: _chatController,
                          onSend: _onSend,
                          onGift: _onGiftTap,
                          onMembers: _onMembersTap,
                          onMore: _onMoreTap,
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

class _TipsyBarChatTopBar extends StatelessWidget {
  const _TipsyBarChatTopBar({
    required this.scale,
    required this.topInset,
    required this.host,
    required this.joinedSeat,
    required this.micOn,
    required this.soundOn,
    required this.onBack,
    required this.onMicTap,
    required this.onSoundTap,
  });

  final double scale;
  final double topInset;
  final TipsyBarChatMember? host;
  final bool joinedSeat;
  final bool micOn;
  final bool soundOn;
  final VoidCallback onBack;
  final VoidCallback onMicTap;
  final VoidCallback onSoundTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final hostMember = host;

    return Padding(
      padding: EdgeInsets.fromLTRB(8 * s, 4 * s, 12 * s, 8 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnBack,
              width: 40 * s,
              height: 40 * s,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8 * s),
          if (hostMember != null)
            HostInfoBar(
              width: HostInfoBar.compactWidth * s,
              avatarUrl: hostMember.avatarUrl,
              avatarCacheKey: hostMember.avatarPath,
              name: hostMember.displayName,
              email: hostMember.email,
              userId: hostMember.userId,
              onAvatarTap: () => openStarProfileForUser(
                context,
                userId: hostMember.userId,
                name: hostMember.displayName,
                email: hostMember.email,
                imageUrl: hostMember.avatarUrl,
              ),
              trailing: FollowActionButton(
                userId: hostMember.userId,
                size: 28 * s,
                addAsset: TipsyBarChatAssets.btnFollowAdd,
                checkAsset: CircleAssets.btnFollowCheck,
              ),
            ),
          const Spacer(),
          if (joinedSeat && soundOn) ...[
            GestureDetector(
              onTap: onMicTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                micOn
                    ? TipsyBarChatAssets.icMicOn
                    : TipsyBarChatAssets.icMicOff,
                width: 40 * s,
                height: 40 * s,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 8 * s),
          ],
          GestureDetector(
            onTap: onSoundTap,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              soundOn
                  ? TipsyBarChatAssets.btnSound
                  : TipsyBarChatAssets.icSoundOff,
              width: 40 * s,
              height: 40 * s,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsyBarChatMessageList extends StatelessWidget {
  const _TipsyBarChatMessageList({
    required this.scale,
    required this.messages,
    required this.scrollController,
  });

  final double scale;
  final List<TipsyBarChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: 12 * s),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        if (msg.isSystem) {
          return Padding(
            padding: EdgeInsets.only(bottom: 10 * s),
            child: _TipsBanner(scale: s, text: msg.text),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: 10 * s),
          child: _UserMessageBubble(scale: s, message: msg),
        );
      },
    );
  }
}

class _TipsBanner extends StatelessWidget {
  const _TipsBanner({required this.scale, required this.text});

  final double scale;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            TipsyBarChatAssets.icTips,
            width: 28 * s,
            height: 28 * s,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 8 * s),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12 * s,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.scale, required this.message});

  final double scale;
  final TipsyBarChatMessage message;

  void _onAvatarTap(BuildContext context) {
    final id = message.senderId?.trim();
    if (id == null || id.isEmpty) return;
    openStarProfileForUser(
      context,
      userId: id,
      name: message.senderName,
      imageUrl: message.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final avatarSize = 32 * s;
    final canOpenProfile = message.senderId?.trim().isNotEmpty ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: canOpenProfile ? () => _onAvatarTap(context) : null,
          behavior: HitTestBehavior.opaque,
          child: ClipOval(
            child: message.avatarUrl != null && message.avatarUrl!.isNotEmpty
                ? CachedMediaImage(
                    url: message.avatarUrl!,
                    width: avatarSize,
                    height: avatarSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _avatarPlaceholder(avatarSize),
                  )
                : _avatarPlaceholder(avatarSize),
          ),
        ),
        SizedBox(width: 8 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 4 * s),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14 * s),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 13 * s,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder(double size) {
    return ColoredBox(
      color: const Color(0xFFE8E4DC),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.person, size: size * 0.5, color: Colors.black38),
      ),
    );
  }
}

class _TipsyBarSeatsColumn extends StatelessWidget {
  const _TipsyBarSeatsColumn({
    required this.scale,
    required this.detail,
    required this.joinedSeat,
    required this.isRoomHost,
    required this.micOn,
    required this.soundOn,
    required this.onJoinTap,
    required this.onLeaveSeat,
  });

  final double scale;
  final TipsyBarChatRoomDetail? detail;
  final bool joinedSeat;
  final bool isRoomHost;
  final bool micOn;
  final bool soundOn;
  final VoidCallback onJoinTap;
  final VoidCallback onLeaveSeat;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    const seatSize = 72.0;
    final slots = <_SeatSlot>[];

    // 麦位：1 房主，2–3 嘉宾，4–5 空位 Join in。
    final members = detail?.members ?? [];
    for (var i = 0; i < TipsyBarChatRoomDetail.seatCount; i++) {
      if (i < members.length && !members[i].isVacantSeat) {
        slots.add(_SeatSlot(member: members[i]));
      } else if (!isRoomHost &&
          i >= TipsyBarChatRoomDetail.joinSeatIndexStart &&
          joinedSeat &&
          i == members.length &&
          AuthService.cachedProfile != null) {
        final p = AuthService.cachedProfile!;
        slots.add(
          _SeatSlot(
            member: TipsyBarChatMember(
              userId: p.id,
              displayName: p.displayName,
              email: p.email,
              avatarUrl: p.avatarUrl,
              avatarPath: p.avatarPath,
              isSpeaking: micOn && soundOn,
            ),
            isSelf: true,
          ),
        );
      } else {
        slots.add(const _SeatSlot());
      }
    }

    return SizedBox(
      width: seatSize * s + 8,
      child: Column(
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0) SizedBox(height: 10 * s),
            _SeatTile(
              scale: s,
              size: seatSize * s,
              slot: slots[i],
              showMicIndicator: soundOn,
              showJoinIn: !joinedSeat &&
                  !isRoomHost &&
                  i >= TipsyBarChatRoomDetail.joinSeatIndexStart,
              onJoinTap: onJoinTap,
              onLeaveSeat: onLeaveSeat,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatSlot {
  const _SeatSlot({this.member, this.isSelf = false});

  final TipsyBarChatMember? member;
  final bool isSelf;
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.scale,
    required this.size,
    required this.slot,
    required this.showMicIndicator,
    required this.showJoinIn,
    required this.onJoinTap,
    required this.onLeaveSeat,
  });

  final double scale;
  final double size;
  final _SeatSlot slot;
  final bool showMicIndicator;
  final bool showJoinIn;
  final VoidCallback onJoinTap;
  final VoidCallback onLeaveSeat;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final member = slot.member;

    if (member == null || member.isVacantSeat) {
      final joinInExtra = showJoinIn ? 28 * s : 0.0;
      return SizedBox(
        width: size,
        height: size + joinInExtra,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Image.asset(
              TipsyBarChatAssets.seatEmpty,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
            if (showJoinIn)
              Positioned(
                bottom: 0,
                child: GestureDetector(
                  onTap: onJoinTap,
                  behavior: HitTestBehavior.opaque,
                  child: Image.asset(
                    TipsyBarChatAssets.btnJoinIn,
                    height: 32 * s,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    const crownSize = 26.0;
    final crownH = crownSize * s;
    final hostTopPad = member.isHost ? crownH * 0.52 : 0.0;

    final userId = member.userId.trim();
    final canOpenProfile = userId.isNotEmpty;

    return SizedBox(
      width: size,
      height: size + hostTopPad,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          GestureDetector(
            onTap: canOpenProfile
                ? () => openStarProfileForUser(
                      context,
                      userId: userId,
                      name: member.displayName,
                      email: member.email,
                      imageUrl: member.avatarUrl,
                    )
                : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: member.avatarUrl != null &&
                            member.avatarUrl!.isNotEmpty
                        ? CachedMediaImage(
                            url: member.avatarUrl!,
                            cacheKey: member.avatarPath,
                            fit: BoxFit.cover,
                          )
                        : ColoredBox(
                            color: const Color(0xFFE8E4DC),
                            child: Icon(Icons.person, size: size * 0.45),
                          ),
                  ),
                  if (showMicIndicator && member.isSpeaking)
                    ClipOval(
                      child: Image.asset(
                        TipsyBarChatAssets.icMicActive,
                        width: size,
                        height: size,
                        fit: BoxFit.cover,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (member.isHost)
            Positioned(
              bottom: size - crownH * 0.38,
              left: size * 0.52,
              child: Image.asset(
                TipsyBarChatAssets.icCrown,
                width: crownH,
                height: crownH,
                fit: BoxFit.contain,
              ),
            ),
          if (slot.isSelf)
            Positioned(
              right: -2 * s,
              bottom: -2 * s,
              child: GestureDetector(
                onTap: onLeaveSeat,
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  TipsyBarChatAssets.icLeaveSeat,
                  width: 28 * s,
                  height: 28 * s,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TipsyBarChatBottomBar extends StatelessWidget {
  const _TipsyBarChatBottomBar({
    required this.scale,
    required this.bottomInset,
    required this.controller,
    required this.onSend,
    required this.onGift,
    required this.onMembers,
    required this.onMore,
  });

  static const _sendButtonSize = 34.0;

  final double scale;
  final double bottomInset;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onGift;
  final VoidCallback onMembers;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final sendSize = _sendButtonSize * s;

    return Padding(
      padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 8 * s + bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 48 * s,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24 * s),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TextStyle(
                        fontSize: 15 * s,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Please enter...',
                        hintStyle: TextStyle(
                          fontSize: 15 * s,
                          color: Colors.black.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(
                          left: 16 * s,
                          right: sendSize + 12 * s,
                          top: 12 * s,
                          bottom: 12 * s,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 7 * s),
                    child: GestureDetector(
                      onTap: onSend,
                      behavior: HitTestBehavior.opaque,
                      child: Image.asset(
                        TipsyBarChatAssets.btnSend,
                        width: sendSize,
                        height: sendSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8 * s),
          GestureDetector(
            onTap: onGift,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnGift,
              width: 44 * s,
              height: 44 * s,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8 * s),
          GestureDetector(
            onTap: onMembers,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnMembers,
              width: 44 * s,
              height: 44 * s,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 8 * s),
          GestureDetector(
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              TipsyBarChatAssets.btnMore,
              width: 44 * s,
              height: 44 * s,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
