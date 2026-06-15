// 私信视频通话等待页（无额外状态，仅持有 peer）。
import 'package:get/get.dart';
import 'package:hilmi/models/direct_chat_peer.dart';

class DirectVideoCallController extends GetxController {
  DirectVideoCallController({required this.peer});

  final DirectChatPeer peer;
}
