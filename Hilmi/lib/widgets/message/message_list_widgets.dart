import 'package:flutter/material.dart';
import 'package:hilmi/widgets/coin_balance_bar.dart';
import 'package:hilmi/models/message_conversation.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:hilmi/widgets/home_widgets.dart';
import 'package:hilmi/widgets/message/message_assets.dart';
import 'package:hilmi/widgets/message/message_list_layout.dart';

/// 顶部：Message 标题 + 金币条（与 Discover 一致）。
class MessageListHeader extends StatelessWidget {
  const MessageListHeader({super.key, required this.coinBalance});

  final int coinBalance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            MessageAssets.titleMessage,
            height: 44,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
          const Spacer(),
          CoinBalanceBar(
            coinBalance: coinBalance,
            borderWidth: MessageListLayout.borderWidth,
          ),
        ],
      ),
    );
  }
}

/// 横滑推荐用户大卡（与首页 Discover 明星卡同款）。
class MessageFeaturedUsersRow extends StatelessWidget {
  const MessageFeaturedUsersRow({
    super.key,
    required this.users,
    this.onProfileTap,
    this.onChatTap,
  });

  final List<MessageFeaturedUser> users;
  final void Function(MessageFeaturedUser user)? onProfileTap;
  final void Function(MessageFeaturedUser user)? onChatTap;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: MessageListLayout.featuredRowH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          return HomeProfileDiscoverCard(
            imageUrl: user.avatarUrl,
            onProfileTap:
                onProfileTap == null ? null : () => onProfileTap!(user),
            onChatTap:
                onChatTap == null ? null : () => onChatTap!(user),
          );
        },
      ),
    );
  }
}

/// All Chat 筛选胶囊（切图）。
class MessageAllChatChip extends StatelessWidget {
  const MessageAllChatChip({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 8 * scale),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          MessageAssets.btnAllChat,
          height: MessageListLayout.allChatH * scale,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 单条会话：左滑露出右侧垃圾桶（仅隐藏列表项，不删聊天记录）。
class MessageConversationTile extends StatefulWidget {
  const MessageConversationTile({
    super.key,
    required this.conversation,
    required this.scale,
    this.revealed = false,
    this.onReveal,
    this.onClose,
    this.onTap,
    this.onDelete,
  });

  final MessageConversation conversation;
  final double scale;
  final bool revealed;
  final VoidCallback? onReveal;
  final VoidCallback? onClose;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  State<MessageConversationTile> createState() =>
      _MessageConversationTileState();

  static String formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MessageConversationTileState extends State<MessageConversationTile> {
  double _dragOffset = 0;

  double get _deleteButtonW =>
      MessageListLayout.deleteButtonW * widget.scale;

  double get _deleteButtonH =>
      MessageListLayout.deleteButtonH * widget.scale;

  double get _revealGap => MessageListLayout.deleteRevealGap * widget.scale;

  double get _maxReveal => _deleteButtonW + _revealGap;

  bool get _deleteRevealed => _dragOffset < 0;

  @override
  void didUpdateWidget(covariant MessageConversationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.revealed && _dragOffset != 0) {
      setState(() => _dragOffset = 0);
    }
  }

  void _applyOffset(double offset) {
    final clamped = offset.clamp(-_maxReveal, 0.0);
    if (clamped == _dragOffset) return;
    setState(() => _dragOffset = clamped);
    if (clamped == 0) {
      widget.onClose?.call();
    } else if (clamped <= -_maxReveal / 2) {
      widget.onReveal?.call();
    }
  }

  void _onDeleteTap() {
    if (_dragOffset >= 0) return;
    widget.onDelete?.call();
    setState(() => _dragOffset = 0);
    widget.onClose?.call();
  }

  void _onCardTap() {
    if (_dragOffset < 0) {
      _applyOffset(0);
      return;
    }
    widget.onTap?.call();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onDelete == null) return;
    final next = (_dragOffset + details.delta.dx).clamp(-_maxReveal, 0.0);
    if (next < 0 && _dragOffset == 0) {
      widget.onReveal?.call();
    }
    setState(() => _dragOffset = next);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.onDelete == null) return;
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity < -200 || _dragOffset < -_maxReveal / 2;
    _applyOffset(open ? -_maxReveal : 0);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final conversation = widget.conversation;
    final avatar = MessageListLayout.conversationAvatar * scale;
    final padV = MessageListLayout.conversationRowPadV * scale;

    final cardContent = Padding(
      padding: EdgeInsets.fromLTRB(14 * scale, padV, 14 * scale, padV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14 * scale),
            child: SizedBox(
              width: avatar,
              height: avatar,
              child: _ConversationAvatar(url: conversation.peerAvatarUrl),
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        conversation.peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Text(
                      MessageConversationTile.formatTime(
                        conversation.lastMessageAt,
                      ),
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2 * scale),
                Text(
                  conversation.displayPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.45),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final bgH = MessageListLayout.chatRowHeightForWidth(width);

          final card = SizedBox(
            width: width,
            height: bgH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  MessageAssets.chatRowBg,
                  width: width,
                  height: bgH,
                  fit: BoxFit.fill,
                ),
                cardContent,
              ],
            ),
          );

          if (widget.onDelete == null) {
            return GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: card,
            );
          }

          return SizedBox(
            height: bgH,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerRight,
              children: [
                Positioned(
                  right: 0,
                  top: (bgH - _deleteButtonH) / 2 -
                      MessageListLayout.deleteButtonUpOffset * widget.scale,
                  width: _deleteButtonW,
                  height: _deleteButtonH,
                  child: IgnorePointer(
                    child: Image.asset(
                      MessageAssets.btnDelete,
                      width: _deleteButtonW,
                      height: _deleteButtonH,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _onCardTap,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  behavior: HitTestBehavior.opaque,
                  child: Transform.translate(
                    offset: Offset(_dragOffset, 0),
                    child: card,
                  ),
                ),
                if (_deleteRevealed)
                  Positioned(
                    right: 0,
                    top: (bgH - _deleteButtonH) / 2 -
                        MessageListLayout.deleteButtonUpOffset * widget.scale,
                    width: _deleteButtonW,
                    height: _deleteButtonH,
                    child: GestureDetector(
                      onTap: _onDeleteTap,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedMediaImage(
        url: url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE8E4DC),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline,
        size: 28,
        color: Color(0xFFB8B2A8),
      ),
    );
  }
}

/// 列表为空时的占位（仅图标，对齐设计稿）。
class MessageListEmptyPlaceholder extends StatelessWidget {
  const MessageListEmptyPlaceholder({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = MessageListLayout.emptyIconSize * scale;
    return Center(
      child: Image.asset(
        MessageAssets.emptyMartini,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
