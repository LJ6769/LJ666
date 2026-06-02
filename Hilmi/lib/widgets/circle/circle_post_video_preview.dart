import 'package:flutter/material.dart';
import 'package:hilmi/core/circle_video_playback.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:video_player/video_player.dart';

/// 朋友圈视频：列表仅封面；详情页点击后再签名并播放（减少 Storage egress）。
class CirclePostVideoPreview extends StatefulWidget {
  const CirclePostVideoPreview({
    super.key,
    required this.videoPath,
    required this.posterUrl,
    this.posterCacheKey,
    this.playbackEnabled = false,
    this.isActive = true,
    this.fit = BoxFit.cover,
    this.playIconSize = 56,
    this.resolveVideoUrl,
  });

  final String? videoPath;
  final String posterUrl;
  final String? posterCacheKey;
  final bool playbackEnabled;
  final bool isActive;
  final BoxFit fit;
  final double playIconSize;

  /// 进详情时可传入；仅在用户点击播放时调用，优先走签名缓存。
  final Future<String?> Function(String videoPath)? resolveVideoUrl;

  @override
  State<CirclePostVideoPreview> createState() => _CirclePostVideoPreviewState();
}

class _CirclePostVideoPreviewState extends State<CirclePostVideoPreview> {
  final _playbackToken = Object();

  VideoPlayerController? _controller;
  int _prepareGeneration = 0;
  bool _failed = false;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant CirclePostVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _reset();
      return;
    }
    if (oldWidget.isActive && !widget.isActive) {
      _pauseToPoster();
      if (widget.playbackEnabled) {
        CircleVideoPlayback.instance.release(_playbackToken);
      }
    }
  }

  Future<String?> _playbackUrl() async {
    final path = widget.videoPath?.trim() ?? '';
    if (path.isEmpty) return null;

    final cached = StorageMediaUrlResolver.lookup(path);
    if (cached.isNotEmpty) return cached;

    return widget.resolveVideoUrl?.call(path);
  }

  Future<void> _prepare() async {
    if (!widget.playbackEnabled) return;

    final url = await _playbackUrl();
    if (url == null ||
        url.isEmpty ||
        !StorageMediaUrlResolver.isValidSignedMediaUrl(url)) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final generation = ++_prepareGeneration;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || generation != _prepareGeneration) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.pause();
      await controller.seekTo(Duration.zero);
      setState(() {
        _failed = false;
        _initialized = true;
        _isPlaying = false;
      });
    } catch (error) {
      debugPrint('[CirclePostVideoPreview] Load failed: $error');
      await controller.dispose();
      if (mounted && generation == _prepareGeneration) {
        _controller = null;
        setState(() {
          _failed = true;
          _initialized = false;
        });
      }
    }
  }

  Future<void> _onTapToggle() async {
    if (!widget.playbackEnabled || !widget.isActive || _failed) return;

    if (!_initialized) {
      if (_loading) return;
      setState(() => _loading = true);
      await _prepare();
      if (!mounted) return;
      setState(() => _loading = false);
      if (_failed || !_initialized) return;
    }

    final controller = _controller;
    if (controller == null) return;

    if (_isPlaying) {
      await _pauseForUser();
      return;
    }

    await CircleVideoPlayback.instance.activate(
      token: _playbackToken,
      onDeactivate: _pauseToPoster,
      onResume: _resumeAfterOverlay,
    );
    if (!mounted) return;

    setState(() => _isPlaying = true);
    try {
      await controller.setVolume(1);
      await controller.play();
    } catch (error) {
      debugPrint('[CirclePostVideoPreview] Playback failed: $error');
      await CircleVideoPlayback.instance.release(_playbackToken);
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _pauseForUser() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.pause();
      await controller.setVolume(0);
    }
    await CircleVideoPlayback.instance.release(_playbackToken);
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _pauseToPoster() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.pause();
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
    }
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _resumeAfterOverlay() async {
    if (!widget.playbackEnabled || !widget.isActive || _failed) return;
    final controller = _controller;
    if (controller == null || !_initialized || !controller.value.isInitialized) {
      return;
    }
    if (!mounted) return;
    setState(() => _isPlaying = true);
    try {
      await controller.setVolume(1);
      await controller.play();
    } catch (error) {
      debugPrint('[CirclePostVideoPreview] Resume after overlay failed: $error');
      await CircleVideoPlayback.instance.release(_playbackToken);
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _failed = true;
        });
      }
    }
  }

  void _reset() {
    _prepareGeneration++;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _isPlaying = false;
    _failed = false;
    _loading = false;
  }

  @override
  void dispose() {
    if (widget.playbackEnabled) {
      CircleVideoPlayback.instance.release(_playbackToken);
    }
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildVideoFrame(VideoPlayerController controller) {
    final video = SizedBox(
      width: controller.value.size.width,
      height: controller.value.size.height,
      child: VideoPlayer(controller),
    );
    return Center(
      child: FittedBox(
        fit: widget.fit,
        clipBehavior: widget.fit == BoxFit.cover ? Clip.hardEdge : Clip.none,
        child: video,
      ),
    );
  }

  Widget _buildPlayButton() {
    return Center(
      child: Container(
        width: widget.playIconSize,
        height: widget.playIconSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.black,
          size: widget.playIconSize * 0.64,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = _initialized &&
        !_failed &&
        controller != null &&
        controller.value.isInitialized;
    final showPlayIcon =
        !widget.playbackEnabled || !_isPlaying || (!ready && !_loading);

    Widget content = Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        const ColoredBox(color: Color(0xFF2A2420)),
        if (!ready && widget.posterUrl.isNotEmpty)
          CachedMediaImage(
            url: widget.posterUrl,
            cacheKey: widget.posterCacheKey,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: Color(0xFF2A2420)),
          ),
        if (ready) _buildVideoFrame(controller),
        if (_loading)
          const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD14D4D),
              ),
            ),
          ),
        if (showPlayIcon && !_loading) _buildPlayButton(),
        if (_failed)
          Center(
            child: Icon(
              Icons.videocam_off_outlined,
              color: Colors.white.withValues(alpha: 0.35),
              size: widget.playIconSize * 0.75,
            ),
          ),
      ],
    );

    if (widget.playbackEnabled) {
      content = GestureDetector(
        onTap: _onTapToggle,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
