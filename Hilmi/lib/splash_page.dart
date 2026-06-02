import 'package:flutter/material.dart';
import 'package:hilmi/config/config.dart';

/// 与 [AppConfig.splashBackground] 一致，保留此别名便于现有 import。
const Color splashBackground = AppConfig.splashBackground;

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(AppConfig.splashDuration, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final iconSize = MediaQuery.sizeOf(context).width * 0.20;

    return Scaffold(
      backgroundColor: splashBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Image.asset(
              'assets/splash/splash_icon_launch.png',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48 + bottomPadding,
            child: const Text(
              'Hilmi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
