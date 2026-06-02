import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/hidden_conversations_service.dart';
import 'package:hilmi/core/message_list_refresh_signal.dart';
import 'package:hilmi/data/message_repository.dart';
import 'package:hilmi/models/direct_chat_message.dart';
import 'package:hilmi/models/direct_chat_peer.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/utils/open_direct_video_call.dart';
import 'package:hilmi/utils/open_star_profile.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/utils/user_handle.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';
import 'package:hilmi/widgets/circle/circle_post_more_sheet.dart';
import 'package:hilmi/widgets/follow/follow_action_button.dart';
import 'package:hilmi/widgets/message/direct_chat_assets.dart';
import 'package:hilmi/widgets/message/direct_chat_layout.dart';

/// 一对一私信聊天页（对齐设计稿）。
class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.peer,
    this.repository = const MessageRepository(),
  });

  final DirectChatPeer peer;
  final MessageRepository repository;

  static const _pageBg = Color(0xFFF8F6FC);
  static const _incomingBubble = Color(0xFF9289C3);
  static const _headerBarColor = Color(0xFF9289C3);

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  List<DirectChatMessage> _messages = const [];
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;

  String? get _myId => AuthService.cachedProfile?.id;

  double _scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / DirectChatLayout.designWidth;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.peer.conversationId;
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    _conversationId ??= await widget.repository.findConversationId(widget.peer.id);

    if (_conversationId != null && _conversationId!.isNotEmpty) {
      final messages =
          await widget.repository.fetchChatMessages(_conversationId!);
      if (mounted) {
        setState(() {
          _messages = messages;
          _loading = false;
        });
        _scrollToBottom();
      }
    } else if (mounted) {
      setState(() {
        _messages = const [];
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _onVideoTap() {
    return openDirectVideoCall(context, peer: widget.peer);
  }

  Future<void> _onMoreTap() async {
    final result = await CirclePostMoreSheet.showForUser(
      context,
      userId: widget.peer.id,
    );
    if (result == CirclePostMoreResult.blacklisted && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onSend() async {
    if (_sending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to send messages')) {
      return;
    }
    if (!mounted) return;

    setState(() => _sending = true);
    dismissKeyboard(context);

    try {
      final message = await widget.repository.sendChatMessage(
        peerId: widget.peer.id,
        body: text,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      _conversationId ??= await widget.repository.findConversationId(widget.peer.id);
      await HiddenConversationsService.unhidePeer(widget.peer.id);
      MessageListRefreshSignal.notify();
      _inputController.clear();
      setState(() {
        _messages = [..._messages, message];
        _sending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final peer = widget.peer;
    final handle = formatUserHandle(email: peer.email, userId: peer.id);
    final myName = AuthService.cachedProfile?.displayName ?? 'Me';
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: DirectChatScreen._headerBarColor,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DirectChatScreen._pageBg,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _DirectChatHeader(
              scale: s,
              peerId: peer.id,
              peerName: peer.name,
              peerEmail: peer.email,
              peerHandle: handle,
              peerAvatarUrl: peer.avatarUrl,
              onMoreTap: _onMoreTap,
              onVideoTap: _onVideoTap,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD14D4D),
                        strokeWidth: 2,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 12 * s),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          if (_messages.isEmpty) return const SizedBox.shrink();
                          final t = _messages.first.createdAt.toLocal();
                          return Padding(
                            padding: EdgeInsets.only(bottom: 16 * s),
                            child: Center(
                              child: Text(
                                _formatClock(t),
                                style: TextStyle(
                                  fontSize: 12 * s,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          );
                        }
                        final message = _messages[index - 1];
                        final isMine = message.senderId == _myId;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 14 * s),
                          child: _DirectChatBubble(
                            scale: s,
                            message: message,
                            isMine: isMine,
                            displayName:
                                isMine ? myName : (message.senderName ?? peer.name),
                            avatarUrl: isMine
                                ? AuthService.cachedProfile?.avatarUrl
                                : (message.senderAvatarUrl ?? peer.avatarUrl),
                          ),
                        );
                      },
                    ),
            ),
            _DirectChatInputBar(
              scale: s,
              bottomInset: bottomInset,
              controller: _inputController,
              sending: _sending,
              onSend: _onSend,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _DirectChatHeader extends StatelessWidget {
  const _DirectChatHeader({
    required this.scale,
    required this.peerId,
    required this.peerName,
    this.peerEmail,
    required this.peerHandle,
    this.peerAvatarUrl,
    required this.onMoreTap,
    required this.onVideoTap,
  });

  final double scale;
  final String peerId;
  final String peerName;
  final String? peerEmail;
  final String peerHandle;
  final String? peerAvatarUrl;
  final VoidCallback onMoreTap;
  final VoidCallback onVideoTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final top = MediaQuery.paddingOf(context).top;
    final headerH = DirectChatLayout.headerH * s;
    final profileH = DirectChatLayout.headerProfileH * s;

    return SizedBox(
      height: top + headerH + 8 * s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + headerH,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: DirectChatScreen._headerBarColor,
              ),
              child: Image.asset(
                DirectChatAssets.headerBg,
                fit: BoxFit.fill,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            top: top + (headerH - profileH) / 2,
            left: 52 * s,
            child: SizedBox(
              width: DirectChatLayout.headerProfileMaxW * s,
              height: profileH,
              child: Container(
                padding: EdgeInsets.fromLTRB(6 * s, 4 * s, 6 * s, 4 * s),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.black,
                    width: DirectChatLayout.bubbleBorderWidth * s,
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => openStarProfileForUser(
                        context,
                        userId: peerId,
                        name: peerName,
                        email: peerEmail,
                        imageUrl: peerAvatarUrl,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: _ChatCapsuleAvatar(
                        url: peerAvatarUrl,
                        size: 32 * s,
                        scale: s,
                      ),
                    ),
                    SizedBox(width: 6 * s),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14 * s,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            peerHandle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11 * s,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.4),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4 * s),
                    FollowActionButton(
                      userId: peerId,
                      size: 28 * s,
                      addAsset: DirectChatAssets.btnAdd,
                      checkAsset: CircleAssets.btnFollowCheck,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + (headerH - 35 * s) / 2,
            left: 12 * s,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                DirectChatAssets.btnBack,
                width: 35 * s,
                height: 35 * s,
              ),
            ),
          ),
          Positioned(
            top: top + (headerH - 36 * s) / 2,
            right: 52 * s,
            child: GestureDetector(
              onTap: onVideoTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                DirectChatAssets.btnVideo,
                width: 36 * s,
                height: 36 * s,
              ),
            ),
          ),
          Positioned(
            top: top + (headerH - 36 * s) / 2,
            right: 12 * s,
            child: GestureDetector(
              onTap: onMoreTap,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                DirectChatAssets.btnMore,
                width: 36 * s,
                height: 36 * s,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectChatBubble extends StatelessWidget {
  const _DirectChatBubble({
    required this.scale,
    required this.message,
    required this.isMine,
    required this.displayName,
    this.avatarUrl,
  });

  final double scale;
  final DirectChatMessage message;
  final bool isMine;
  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final avatar = DirectChatLayout.messageAvatar * s;
    final maxW = MediaQuery.sizeOf(context).width * 0.72;

    final bubble = isMine
        ? _OutgoingBubbleSlice(
            scale: s,
            maxWidth: maxW,
            text: message.body,
          )
        : _IncomingBubble(
            scale: s,
            maxWidth: maxW,
            text: message.body,
          );

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMine) ...[
          _ChatCapsuleAvatar(url: avatarUrl, size: avatar, scale: s),
          SizedBox(width: 6 * s),
        ],
        Text(
          displayName,
          style: TextStyle(
            fontSize: 12 * s,
            fontWeight: FontWeight.w800,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
        if (isMine) ...[
          SizedBox(width: 6 * s),
          _ChatCapsuleAvatar(url: avatarUrl, size: avatar, scale: s),
        ],
      ],
    );

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        meta,
        SizedBox(height: 6 * s),
        bubble,
      ],
    );
  }
}

/// 我方消息：圆角胶囊 + 细黑边（与 bubble_out 切图一致，避免拉伸变形）。
class _OutgoingBubbleSlice extends StatelessWidget {
  const _OutgoingBubbleSlice({
    required this.scale,
    required this.maxWidth,
    required this.text,
  });

  final double scale;
  final double maxWidth;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return _ChatCapsuleBubble(
      maxWidth: maxWidth,
      minHeight: DirectChatLayout.capsuleLogicalH * s,
      backgroundColor: Colors.white,
      borderWidth: DirectChatLayout.bubbleBorderWidth * s,
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14 * s,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          height: 1.35,
        ),
      ),
    );
  }
}

/// 圆角胶囊气泡：高度随文字、圆角自动取半高，边框保持圆滑。
class _ChatCapsuleBubble extends StatelessWidget {
  const _ChatCapsuleBubble({
    required this.maxWidth,
    required this.minHeight,
    required this.backgroundColor,
    required this.borderWidth,
    required this.padding,
    required this.child,
  });

  final double maxWidth;
  final double minHeight;
  final Color backgroundColor;
  final double borderWidth;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        minHeight: minHeight,
      ),
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.black,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 对方消息：紫色胶囊 + 细黑边。
class _IncomingBubble extends StatelessWidget {
  const _IncomingBubble({
    required this.scale,
    required this.maxWidth,
    required this.text,
  });

  final double scale;
  final double maxWidth;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return _ChatCapsuleBubble(
      maxWidth: maxWidth,
      minHeight: DirectChatLayout.capsuleLogicalH * s,
      backgroundColor: DirectChatScreen._incomingBubble,
      borderWidth: DirectChatLayout.bubbleBorderWidth * s,
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14 * s,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.35,
        ),
      ),
    );
  }
}

class _DirectChatInputBar extends StatelessWidget {
  const _DirectChatInputBar({
    required this.scale,
    required this.bottomInset,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final double scale;
  final double bottomInset;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    final barH = DirectChatLayout.inputBarH * s;

    return Padding(
      padding: EdgeInsets.fromLTRB(16 * s, 8 * s, 16 * s, 8 * s + bottomInset),
      child: SizedBox(
        height: barH,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                DirectChatAssets.inputFieldBg,
                fit: BoxFit.fill,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 18 * s, right: 52 * s),
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                onTapOutside: (_) => dismissKeyboard(context),
                style: TextStyle(
                  fontSize: 15 * s,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Please enter...',
                  hintStyle: TextStyle(
                    fontSize: 15 * s,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8 * s,
              child: GestureDetector(
                onTap: sending ? null : onSend,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: sending ? 0.6 : 1,
                  child: Image.asset(
                    DirectChatAssets.btnSend,
                    width: 36 * s,
                    height: 36 * s,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 聊天页头像：胶囊描边 + 细黑边（与消息气泡一致）。
class _ChatCapsuleAvatar extends StatelessWidget {
  const _ChatCapsuleAvatar({
    this.url,
    required this.size,
    required this.scale,
  });

  final String? url;
  final double size;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final border = DirectChatLayout.bubbleBorderWidth * scale;
    final innerRadius = BorderRadius.circular(999);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: innerRadius,
        border: Border.all(color: Colors.black, width: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: _Avatar(url: url, size: size),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedMediaImage(
        url: url!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFFE8E4DC),
      child: Icon(
        Icons.person_outline,
        size: size * 0.55,
        color: const Color(0xFFB8B2A8),
      ),
    );
  }
}
