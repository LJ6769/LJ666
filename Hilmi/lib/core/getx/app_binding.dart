// GetX 全局依赖注入：应用启动时注册常驻 Controller。
import 'package:get/get.dart';
import 'package:hilmi/controllers/app_controller.dart';
import 'package:hilmi/controllers/circle_feed_controller.dart';
import 'package:hilmi/controllers/discover_home_controller.dart';
import 'package:hilmi/controllers/home_shell_controller.dart';
import 'package:hilmi/controllers/messages_controller.dart';
import 'package:hilmi/controllers/profile_controller.dart';

/// 应用级 GetX 绑定，在 [GetMaterialApp] 启动时执行一次。
class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppController(), permanent: true);
    Get.put(HomeShellController(), permanent: true);
    Get.put(DiscoverHomeController(), permanent: true);
    Get.put(CircleFeedController(), permanent: true);
    Get.put(ProfileController(), permanent: true);
    Get.put(MessagesController(), permanent: true);
  }
}
