import 'package:hilmi/models/tipsy_bar_chat.dart';

/// 首页/列表卡片：房主头像 + 两个嘉宾空麦位（不足用 null 补齐）。
List<String?> tipsyBarCardParticipantAvatars(List<String?> memberAvatars) {
  final slotCount = TipsyBarChatRoomDetail.cardAvatarSlotCount;
  final result = List<String?>.from(memberAvatars.take(slotCount));
  while (result.length < slotCount) {
    result.add(null);
  }
  return result;
}
