/// 朋友圈视频全局播放协调：同一时刻仅允许一个实例播放。
class CircleVideoPlayback {
  CircleVideoPlayback._();

  static final CircleVideoPlayback instance = CircleVideoPlayback._();

  Object? _activeToken;
  Future<void> Function()? _deactivate;
  Future<void> Function()? _resume;
  bool _pausedForOverlay = false;

  Future<void> activate({
    required Object token,
    required Future<void> Function() onDeactivate,
    Future<void> Function()? onResume,
  }) async {
    if (_activeToken != null && _activeToken != token) {
      await _deactivate?.call();
    }
    _activeToken = token;
    _deactivate = onDeactivate;
    _resume = onResume;
    _pausedForOverlay = false;
  }

  Future<void> release(Object token) async {
    if (_activeToken != token) return;
    _activeToken = null;
    _deactivate = null;
    _resume = null;
    _pausedForOverlay = false;
  }

  /// 登录等全屏页叠在上面时暂停当前朋友圈视频。
  Future<void> pauseForOverlay() async {
    if (_activeToken == null || _pausedForOverlay) return;
    _pausedForOverlay = true;
    await _deactivate?.call();
  }

  /// 从登录页返回后，若仍在播则恢复。
  Future<void> resumeAfterOverlay() async {
    if (!_pausedForOverlay) return;
    _pausedForOverlay = false;
    await _resume?.call();
  }
}
