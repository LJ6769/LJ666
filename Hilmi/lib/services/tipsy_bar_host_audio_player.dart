import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Tipsy Bar 房主语音：首次从 Storage 下载后写入本地缓存，同路径不再重复 egress。
class TipsyBarHostAudioPlayer {
  static final CacheManager _fileCache = CacheManager(
    Config(
      'tipsy_bar_host_audio',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 16,
    ),
  );

  AudioPlayer? _player;
  String? _currentCacheKey;
  bool _disposed = false;

  AudioPlayer _ensurePlayer() {
    if (_disposed) {
      throw StateError('TipsyBarHostAudioPlayer disposed');
    }
    return _player ??= AudioPlayer();
  }

  static bool _isPlayerNotReadyError(Object error) {
    if (error is! PlatformException) return false;
    if (error.code != 'DarwinAudioError') return false;
    final message = error.message ?? '';
    return message.contains('not yet been created') ||
        message.contains('disposed');
  }

  Future<void> _safeStop() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (error) {
      if (_isPlayerNotReadyError(error)) return;
      rethrow;
    }
  }

  /// [cacheKey] 建议传 Storage 对象路径（如 `chat-audio/1.mp3`），与 Signed URL 解耦。
  Future<void> playUrl(String url, {String? cacheKey}) async {
    if (_disposed) return;

    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final key = (cacheKey?.trim().isNotEmpty == true) ? cacheKey!.trim() : trimmed;

    try {
      if (_currentCacheKey == key) {
        await _ensurePlayer().resume();
        return;
      }

      final switchingTrack = _currentCacheKey != null;
      _currentCacheKey = key;

      final file = await _fileCache.getSingleFile(
        trimmed,
        key: key,
        headers: const {},
      );

      if (_disposed) return;

      if (switchingTrack) {
        await _safeStop();
      }

      await _playFile(file.path);
    } catch (error, stack) {
      if (_disposed) return;
      if (_isPlayerNotReadyError(error)) {
        _player = null;
        try {
          final file = await _fileCache.getSingleFile(
            trimmed,
            key: key,
            headers: const {},
          );
          if (_disposed) return;
          await _playFile(file.path);
          return;
        } catch (retryError, retryStack) {
          debugPrint('[TipsyBarHostAudioPlayer] play failed: $retryError');
          debugPrint('$retryStack');
          return;
        }
      }
      debugPrint('[TipsyBarHostAudioPlayer] play failed: $error');
      debugPrint('$stack');
    }
  }

  Future<void> _playFile(String path) async {
    try {
      await _ensurePlayer().play(DeviceFileSource(path));
    } catch (error) {
      if (!_isPlayerNotReadyError(error)) rethrow;
      _player = null;
      await _ensurePlayer().play(DeviceFileSource(path));
    }
  }

  Future<void> pause() async {
    if (_disposed || _player == null) return;
    try {
      await _player!.pause();
    } catch (error) {
      if (_isPlayerNotReadyError(error)) return;
      debugPrint('[TipsyBarHostAudioPlayer] pause: $error');
    }
  }

  Future<void> resume() async {
    if (_disposed) return;
    try {
      await _ensurePlayer().resume();
    } catch (error) {
      if (_isPlayerNotReadyError(error)) return;
      debugPrint('[TipsyBarHostAudioPlayer] resume: $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _currentCacheKey = null;
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (error) {
      debugPrint('[TipsyBarHostAudioPlayer] dispose: $error');
    }
  }
}
