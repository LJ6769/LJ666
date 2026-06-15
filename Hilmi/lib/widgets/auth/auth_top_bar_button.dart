// 登录/注册顶栏返回或 Sign in/up 按钮。
import 'package:flutter/material.dart';

/// 登录/注册顶栏返回或 Sign in / Sign up 按钮（扩大点击区域，置于最上层）。
class AuthTopBarButton extends StatelessWidget {
  const AuthTopBarButton({
    super.key,
    required this.top,
    required this.asset,
    required this.onTap,
    this.left,
    this.right,
    this.size,
    this.width,
    this.height,
  }) : assert(
         size != null || (width != null && height != null),
         'Provide size or both width and height',
       );

  final double top;
  final double? left;
  final double? right;
  /// 方形按钮（如返回）逻辑宽高。
  final double? size;
  /// 胶囊按钮（如 Sign in）逻辑宽。
  final double? width;
  /// 胶囊按钮逻辑高。
  final double? height;
  final String asset;
  final VoidCallback onTap;

  static const _minHit = 48.0;

  @override
  Widget build(BuildContext context) {
    final imageW = width ?? size!;
    final imageH = height ?? size!;
    final hitW = imageW < _minHit ? _minHit : imageW;
    final hitH = imageH < _minHit ? _minHit : imageH;

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(hitH / 2),
          child: SizedBox(
            width: hitW,
            height: hitH,
            child: Center(
              child: Image.asset(
                asset,
                width: imageW,
                height: imageH,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
