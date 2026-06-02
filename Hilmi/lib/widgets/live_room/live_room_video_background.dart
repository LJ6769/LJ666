import 'package:flutter/material.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:video_player/video_player.dart';

/// 直播间全屏视频：加载圈与 Tjgo 一致，就绪后淡入播放。
class LiveRoomVideoBackground extends StatefulWidget {
  const LiveRoomVideoBackground({
    super.key,
    this.videoUrl,
    this.alignment = const Alignment(0, -0.18),
    this.onAspectRatioChanged,
    this.onVideoReady,
    this.onVideoFailed,
  });

  final String? videoUrl;
  final Alignment alignment;
  final ValueChanged<double>? onAspectRatioChanged;
  final VoidCallback? onVideoReady;
  final VoidCallback? onVideoFailed;

  @override
  State<LiveRoomVideoBackground> createState() =>
      LiveRoomVideoBackgroundState();
}

class LiveRoomVideoBackgroundState extends State<LiveRoomVideoBackground> {
  VideoPlayerController? _controller;
  int _prepareGeneration = 0;
  bool _failed = false;
  bool _resumeAfterOverlayPause = false;

  static const _bgColor = Color(0xFF0A0618);

  @override
  void initState() {
    super.initState();
    _attachVideo();
  }

  @override
  void didUpdateWidget(covariant LiveRoomVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      widget.onVideoFailed?.call();
      _disposeController();
      _attachVideo();
    }
  }

  Future<void> _attachVideo() async {
    final url = widget.videoUrl?.trim() ?? '';
    if (url.isEmpty || !StorageMediaUrlResolver.isValidSignedMediaUrl(url)) {
      if (url.isNotEmpty) {
        debugPrint('[LiveRoomVideo] Invalid video URL, skipped: $url');
      }
      _markFailed(notify: true);
      return;
    }

    final generation = ++_prepareGeneration;

    try {
      var controller = await LiveVideoPreloader.claim(url);
      controller ??= VideoPlayerController.networkUrl(Uri.parse(url));

      if (!controller.value.isInitialized) {
        await controller.initialize();
      }

      if (!mounted || generation != _prepareGeneration) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();

      if (!mounted || generation != _prepareGeneration) return;
      final size = controller.value.size;
      if (size.width > 0 && size.height > 0) {
        widget.onAspectRatioChanged?.call(size.width / size.height);
      }
      setState(() => _failed = false);
      widget.onVideoReady?.call();
    } catch (error, stack) {
      debugPrint('[LiveRoomVideo] Load failed $url: $error');
      debugPrint('$stack');
      if (generation == _prepareGeneration && mounted) {
        await _controller?.dispose();
        _controller = null;
        _markFailed(notify: true);
      }
    }
  }

  void _markFailed({bool notify = false}) {
    if (!mounted) return;
    setState(() => _failed = true);
    if (notify) widget.onVideoFailed?.call();
  }

  void _disposeController() {
    _prepareGeneration++;
    _controller?.dispose();
    _controller = null;
    _failed = false;
    _resumeAfterOverlayPause = false;
  }

  /// 登录等全屏页叠在直播间上时暂停播放。
  Future<void> pauseForOverlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _resumeAfterOverlayPause = controller.value.isPlaying;
    if (_resumeAfterOverlayPause) {
      await controller.pause();
    }
  }

  /// 从登录页返回后恢复播放（若此前在播）。
  Future<void> resumeAfterOverlay() async {
    if (!_resumeAfterOverlayPause) return;
    _resumeAfterOverlayPause = false;
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _failed ||
        !mounted) {
      return;
    }
    await controller.play();
  }

  @override
  void dispose() {
    _prepareGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  bool get _showVideo {
    final controller = _controller;
    return !_failed &&
        controller != null &&
        controller.value.isInitialized;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bgColor,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (!_showVideo && !_failed) const _VideoLoadingPlaceholder(),
          if (_showVideo)
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _FullscreenVideo(
                controller: _controller,
                alignment: widget.alignment,
              ),
            ),
          if (_failed) const _FullscreenFallback(),
        ],
      ),
    );
  }
}

class _VideoLoadingPlaceholder extends StatelessWidget {
  const _VideoLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1A1035),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo({
    required this.controller,
    required this.alignment,
  });

  final VideoPlayerController? controller;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final size = c.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: alignment,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}

class _FullscreenFallback extends StatelessWidget {
  const _FullscreenFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.live_tv, color: Colors.white24, size: 64),
    );
  }
}
