// 应用入口：初始化 Supabase、闪屏、新手引导并挂载 HilmiApp。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/controllers/app_controller.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/app_system_ui.dart';
import 'package:hilmi/core/live_video_preloader.dart';
import 'package:hilmi/core/getx/app_binding.dart';
import 'package:hilmi/home_page.dart';
import 'package:hilmi/screens/onboarding/onboarding_screen.dart';
import 'package:hilmi/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LiveVideoPreloader.disposeAll();
  await AppBootstrap.init();
  AppSystemUi.applyLightBackground();
  runApp(const HilmiApp());
}

class HilmiApp extends StatelessWidget {
  const HilmiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.lightBackground,
      child: GetMaterialApp(
      title: 'Hilmi',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBinding(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC84B4B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppConfig.splashBackground,
        useMaterial3: true,
      ),
      builder: (context, child) => child ?? const SizedBox.shrink(),
      home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends GetView<AppController> {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.showSplash.value) {
        return const SplashPage();
      }
      if (controller.showOnboarding.value) {
        return OnboardingScreen(onFinished: controller.onOnboardingFinished);
      }
      return const HomePage();
    });
  }
}
