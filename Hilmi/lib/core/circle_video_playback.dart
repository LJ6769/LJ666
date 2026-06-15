/// 朋友圈视频全局播放协调：同一时刻仅允许一个实例播放。
class CircleVideoPlayback {
  CircleVideoPlayback._();

  static final CircleVideoPlayback instance = CircleVideoPlayback._();

  Object? _activeToken;
  Future<void> Function()? _deactivate;
  Future<void> Function()? _resume;
  Future<void> Function()? _overlayPause;
  Future<void> Function()? _overlayResume;
  bool _pausedForOverlay = false;

  Future<void> activate({
    required Object token,
    required Future<void> Function() onDeactivate,
    Future<void> Function()? onResume,
    Future<void> Function()? onOverlayPause,
    Future<void> Function()? onOverlayResume,
  }) async {
    if (_activeToken != null && _activeToken != token) {
      await _deactivate?.call();
    }
    _activeToken = token;
    _deactivate = onDeactivate;
    _resume = onResume;
    _overlayPause = onOverlayPause;
    _overlayResume = onOverlayResume ?? onResume;
    _pausedForOverlay = false;
  }

  Future<void> release(Object token) async {
    if (_activeToken != token) return;
    _activeToken = null;
    _deactivate = null;
    _resume = null;
    _overlayPause = null;
    _overlayResume = null;
    _pausedForOverlay = false;
  }

  /// 登录 / 个人中心等全屏页叠在上面时暂停当前朋友圈视频（保留进度）。
  Future<void> pauseForOverlay() async {
    if (_activeToken == null || _pausedForOverlay) return;
    _pausedForOverlay = true;
    if (_overlayPause != null) {
      await _overlayPause!();
    } else {
      await _deactivate?.call();
    }
  }

  /// 从叠层页返回后，若仍在播则恢复。
  Future<void> resumeAfterOverlay() async {
    if (!_pausedForOverlay) return;
    _pausedForOverlay = false;
    await (_overlayResume ?? _resume)?.call();
  }
}
