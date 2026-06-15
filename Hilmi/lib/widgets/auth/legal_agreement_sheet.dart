// 用户协议/隐私政策底部弹层。
import 'package:flutter/material.dart';
import 'package:hilmi/widgets/auth/legal_assets.dart';
import 'package:hilmi/widgets/auth/legal_layout.dart';

/// 用户协议 / 隐私政策底部弹层；Confirm 返回 true，关闭返回 false。
class LegalAgreementSheet extends StatelessWidget {
  const LegalAgreementSheet({
    super.key,
    required this.scale,
    required this.title,
    required this.content,
    this.readOnly = false,
  });

  final double scale;
  final String title;
  final String content;
  final bool readOnly;

  static double _scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / LegalLayout.designWidth;

  /// 同时只展示一个 Confirm 弹层；连点登录/注册时复用同一 Future，避免叠两个 EULA。
  static Future<bool>? _confirmInFlight;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final existing = _confirmInFlight;
    if (existing != null) return existing;

    final scale = _scaleOf(context);
    final future = showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height *
              LegalLayout.sheetTopInsetFraction,
        ),
        child: LegalAgreementSheet(
          scale: scale,
          title: title,
          content: content,
        ),
      ),
    ).then((value) => value ?? false);

    _confirmInFlight = future;
    return future.whenComplete(() {
      if (identical(_confirmInFlight, future)) {
        _confirmInFlight = null;
      }
    });
  }

  static Future<void> showReadOnly(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final scale = _scaleOf(context);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height *
              LegalLayout.sheetTopInsetFraction,
        ),
        child: LegalAgreementSheet(
          scale: scale,
          title: title,
          content: content,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final sheetHeight = LegalLayout.sheetHeight * s;
    final horizontalPad = LegalLayout.headerPadH * s;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: sheetHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LegalLayout.cream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LegalLayout.sheetRadius * s),
          ),
          border: Border.all(
            color: Colors.black,
            width: LegalLayout.borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: LegalLayout.headerTop * s),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: LegalLayout.titleSize * s,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () =>
                          Navigator.of(context).pop(readOnly ? null : false),
                      behavior: HitTestBehavior.opaque,
                      child: Image.asset(
                        LegalAssets.icClose,
                        width: LegalLayout.closeSize * s,
                        height: LegalLayout.closeSize * s,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: LegalLayout.headerToBody * s),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: LegalLayout.bodyPadH * s,
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  radius: Radius.circular(4 * s),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 8 * s),
                    child: Text(
                      content.trim(),
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.85),
                        fontSize: LegalLayout.bodySize * s,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                LegalLayout.confirmTop * s,
                horizontalPad,
                LegalLayout.confirmBottom * s + bottomPad,
              ),
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).pop(readOnly ? null : true),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: LegalLayout.confirmH * s,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          LegalAssets.btnConfirm,
                          fit: BoxFit.fill,
                        ),
                      ),
                      Text(
                        readOnly ? 'Close' : 'Confirm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: LegalLayout.confirmTextSize * s,
                          fontWeight: FontWeight.w800,
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
    );
  }
}
