// 全屏页叠在直播/聊天/视频上时暂停底层音视频。
import 'package:hilmi/core/circle_video_playback.dart';

/// 登录、个人中心等全屏页叠在直播间 / 聊天室 / 朋友圈上时，暂停底层音视频。
abstract final class ForegroundMediaPause {
  static ForegroundMediaHandle? _active;
  static bool _overlayPaused = false;

  static void register(ForegroundMediaHandle handle) {
    _active = handle;
  }

  static void unregister(ForegroundMediaHandle handle) {
    if (_active == handle) {
      _active = null;
      _overlayPaused = false;
    }
  }

  static Future<void> pauseForOverlay() async {
    if (_overlayPaused) return;
    _overlayPaused = true;
    await Future.wait([
      if (_active != null) _active!.pause(),
      CircleVideoPlayback.instance.pauseForOverlay(),
    ]);
  }

  static Future<void> resumeAfterOverlay() async {
    if (!_overlayPaused) return;
    _overlayPaused = false;
    await CircleVideoPlayback.instance.resumeAfterOverlay();
    await _active?.resume();
  }
}

/// 由直播间 / Tipsy 聊天室注册；[pause] / [resume] 在打开登录页、个人中心前后调用。
class ForegroundMediaHandle {
  const ForegroundMediaHandle({
    required this.pause,
    required this.resume,
  });

  final Future<void> Function() pause;
  final Future<void> Function() resume;
}
