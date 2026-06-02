import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/onboarding_service.dart';
import 'home_page.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'splash_page.dart';

const Color _splashBackground = Color(0xFFFEFAEF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: _splashBackground,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const HilmiApp());
}

class HilmiApp extends StatefulWidget {
  const HilmiApp({super.key});

  @override
  State<HilmiApp> createState() => _HilmiAppState();
}

class _HilmiAppState extends State<HilmiApp> {
  bool _showSplash = true;
  bool _showOnboarding = false;

  Future<void> _onSplashFinished() async {
    final completed = await OnboardingService.hasCompletedOnboarding();
    if (!mounted) return;
    setState(() {
      _showSplash = false;
      _showOnboarding = !completed;
    });
  }

  void _onOnboardingFinished() {
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hilmi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC84B4B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: _splashBackground,
        useMaterial3: true,
      ),
      builder: (context, child) => child ?? const SizedBox.shrink(),
      home: _showSplash
          ? SplashPage(onFinished: _onSplashFinished)
          : _showOnboarding
              ? OnboardingScreen(onFinished: _onOnboardingFinished)
              : const HomePage(),
    );
  }
}
