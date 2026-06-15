// 直播间顶部社区提示横幅。
import 'package:flutter/material.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

class LiveRoomTipsBanner extends StatelessWidget {
  const LiveRoomTipsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              LiveRoomAssets.tipsMegaphone,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Tips: ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: LiveRoomAssets.tipsMessage),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
