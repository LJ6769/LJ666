// 路由级 GetX 页面：进入时创建 Controller，退出时自动销毁。
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

typedef GetxControllerFactory<T extends GetxController> = T Function();

/// 包裹任意页面，在进入路由时 [create] Controller，pop 时回收。
///
/// Controller 由 State 持有并手动走 onStart/onDelete 生命周期，不注册到
/// Get 全局容器，避免与 [Navigator.push] + SmartManagement 冲突导致白屏。
/// 子树用 [Obx] 监听 `.obs`。
class GetxScreen<T extends GetxController> extends StatefulWidget {
  const GetxScreen({
    super.key,
    required this.create,
    required this.builder,
    this.tag,
    this.autoRemove = true,
  });

  final GetxControllerFactory<T> create;
  final Widget Function(T controller) builder;

  /// 保留参数以兼容旧调用；路由级页面不再写入 Get 全局注册表。
  final String? tag;
  final bool autoRemove;

  @override
  State<GetxScreen<T>> createState() => _GetxScreenState<T>();
}

class _GetxScreenState<T extends GetxController> extends State<GetxScreen<T>> {
  late final T _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.create();
    _controller.onStart();
  }

  @override
  void dispose() {
    _controller.onDelete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_controller);
  }
}
