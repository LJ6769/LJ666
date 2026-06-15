// 直播间底部输入栏与礼物/观众按钮。
import 'package:flutter/material.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

class LiveRoomBottomBar extends StatelessWidget {
  const LiveRoomBottomBar({
    super.key,
    required this.chatController,
    required this.onSend,
    this.onGift,
    this.onViewers,
    this.onMore,
  });

  static const _sendButtonSize = 34.0;

  final TextEditingController chatController;
  final VoidCallback onSend;
  final VoidCallback? onGift;
  final VoidCallback? onViewers;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chatController,
                      onTapOutside: (_) => dismissKeyboard(context),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Please enter...',
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFBDBDBD),
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(
                          left: 18,
                          right: _sendButtonSize + 12,
                          top: 12,
                          bottom: 12,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: _SendButton(
                      size: _sendButtonSize,
                      onTap: onSend,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ActionButton(
            asset: LiveRoomAssets.gift,
            onTap: onGift,
          ),
          const SizedBox(width: 10),
          _ActionButton(
            asset: LiveRoomAssets.viewers,
            onTap: onViewers,
          ),
          const SizedBox(width: 10),
          _ActionButton(
            asset: LiveRoomAssets.more,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

/// 输入框内红色发送键切图。
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.size,
    required this.onTap,
  });

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        LiveRoomAssets.send,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.asset,
    this.onTap,
  });

  final String asset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
      ),
    );
  }
}
