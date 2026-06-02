import 'dart:io';

import 'package:flutter/material.dart';

/// 注册第二步本地头像预览（异步读文件，避免 [Image.file] 在路由销毁后仍 rebuild）。
class SignupAvatarPreview extends StatefulWidget {
  const SignupAvatarPreview({
    super.key,
    required this.filePath,
    required this.size,
    required this.borderRadius,
    required this.placeholder,
  });

  final String filePath;
  final double size;
  final double borderRadius;
  final Widget placeholder;

  @override
  State<SignupAvatarPreview> createState() => _SignupAvatarPreviewState();
}

class _SignupAvatarPreviewState extends State<SignupAvatarPreview> {
  MemoryImage? _image;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant SignupAvatarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final generation = ++_loadGeneration;
    final file = File(widget.filePath);
    if (!file.existsSync()) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _image = null);
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _image = MemoryImage(bytes));
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _image = null);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _image?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return widget.placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image(
        key: ValueKey(widget.filePath),
        image: image,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => widget.placeholder,
      ),
    );
  }
}
