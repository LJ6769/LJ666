// 删除朋友圈帖子确认弹窗。
import 'package:flutter/material.dart';
import 'package:hilmi/widgets/settings/settings_assets.dart';

/// 删除帖子确认弹窗（对齐设计稿）。
class CircleDeletePostDialog extends StatelessWidget {
  const CircleDeletePostDialog({super.key, required this.scale});

  final double scale;

  static const _designWidth = 375.0;
  static const _panelDesignWidth = 319.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static const _message =
      'Are you sure you want to delete this post? Once deleted, '
      'this action cannot be undone!';

  /// 确认删除返回 true，取消返回 false。
  static Future<bool?> show(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (context) => CircleDeletePostDialog(scale: scale),
    );
  }

  double get _s => scale;

  @override
  Widget build(BuildContext context) {
    final panelW = _panelDesignWidth * _s;
    final btnHeight = 40 * _s;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelW,
          padding: EdgeInsets.fromLTRB(20 * _s, 20 * _s, 20 * _s, 18 * _s),
          decoration: BoxDecoration(
            color: _panelColor,
            borderRadius: BorderRadius.circular(20 * _s),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete Post',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18 * _s,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 14 * _s),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF6B5B4F),
                  fontSize: 14 * _s,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 18 * _s),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: btnHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22 * _s),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15 * _s,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * _s),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: btnHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                SettingsAssets.btnConfirm,
                                fit: BoxFit.fill,
                              ),
                            ),
                            Text(
                              'Confirm',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14 * _s,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
