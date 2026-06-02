import 'package:flutter/foundation.dart';

/// 通知消息列表重新拉取会话（发消息、从聊天页返回、切到消息 Tab 等）。
abstract final class MessageListRefreshSignal {
  static final notifier = ValueNotifier<int>(0);

  static void notify() => notifier.value++;
}
