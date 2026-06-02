import 'package:flutter/material.dart';
import 'package:hilmi/widgets/circle/circle_assets.dart';

/// 创建聊天室成功提示（点击 OK 后由调用方关闭创建页并进入房间）。
class TipsyBarRoomCreateSuccessDialog extends StatelessWidget {
  const TipsyBarRoomCreateSuccessDialog({super.key, required this.scale});

  final double scale;

  static const _designWidth = 375.0;
  static const _panelDesignWidth = 319.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static const _title = 'Room Created!';
  static const _message = 'Your chat room has been created successfully.';
  static const _okBtnAspect = 1005 / 153;

  static Future<void> show(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: false,
      builder: (context) => TipsyBarRoomCreateSuccessDialog(scale: scale),
    );
  }

  double get _s => scale;

  @override
  Widget build(BuildContext context) {
    final panelW = _panelDesignWidth * _s;
    final okBtnWidth = panelW - 40 * _s;
    final okBtnHeight = okBtnWidth / _okBtnAspect;

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
                _title,
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
              Align(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: okBtnWidth,
                    height: okBtnHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            CircleAssets.dialogBtnOk,
                            fit: BoxFit.fill,
                          ),
                        ),
                        Text(
                          'OK',
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
        ),
      ),
    );
  }
}
