// 直播间全屏视频背景与加载占位。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/services/cached_media_file_loader.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:video_player/video_player.dart';

/// 直播间全屏视频：加载圈与 Tjgo 一致，就绪后淡入播放。
class LiveRoomVideoBackground extends StatefulWidget {
  const LiveRoomVideoBackground({
    super.key,
    this.videoUrl,
    this.alignment = const Alignment(0, -0.55),
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
    if (url.isEmpty) {
      _markFailed(notify: true);
      return;
    }

    final generation = ++_prepareGeneration;
    final cacheKey = CachedMediaFileLoader.resolveKey(url);

    try {
      var controller = await LiveVideoPreloader.claim(url, cacheKey: cacheKey);
      if (controller == null) {
        if (!StorageMediaUrlResolver.isValidSignedMediaUrl(url)) {
          debugPrint('[LiveRoomVideo] Invalid video URL, skipped: $url');
          _markFailed(notify: true);
          return;
        }
        controller = await CachedMediaFileLoader.createVideoController(
          url: url,
          cacheKey: cacheKey,
        );
      }

      if (!controller.value.isInitialized) {
        await controller.initialize();
      }

      if (!mounted || generation != _prepareGeneration) {
        await _releaseController(controller);
        return;
      }

      _controller = controller;
      await controller.setLooping(true);
      await controller.setVolume(1);
      if (!mounted || generation != _prepareGeneration) {
        await _releaseController(controller);
        _controller = null;
        return;
      }
      await controller.play();

      if (!mounted || generation != _prepareGeneration) {
        await _releaseController(controller);
        _controller = null;
        return;
      }
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
        final stale = _controller;
        _controller = null;
        if (stale != null) {
          await _releaseController(stale);
        }
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
    final controller = _controller;
    _controller = null;
    _failed = false;
    _resumeAfterOverlayPause = false;
    if (controller != null) {
      unawaited(_releaseController(controller));
    }
  }

  Future<void> _releaseController(VideoPlayerController controller) async {
    try {
      if (controller.value.isInitialized) {
        await controller.pause();
        await controller.setVolume(0);
      }
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  /// 退房或页面销毁：立即停止并释放，避免路由退出后仍听到声音。
  Future<void> stopPlayback() async {
    _prepareGeneration++;
    final controller = _controller;
    _controller = null;
    _failed = false;
    _resumeAfterOverlayPause = false;
    if (controller != null) {
      await _releaseController(controller);
    }
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
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isInitialized) {
        controller.pause();
        controller.setVolume(0);
      }
      controller.dispose();
    }
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
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (!_showVideo && !_failed) const LiveRoomVideoLoadingIndicator(),
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
    );
  }
}

/// 视频区域加载圈（无底色，叠在直播间背景上）。
class LiveRoomVideoLoadingIndicator extends StatelessWidget {
  const LiveRoomVideoLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Color(0xFF7C3AED),
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
        fit: BoxFit.cover,
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
