import 'package:flutter/material.dart';
import 'package:hilmi/widgets/auth/legal_assets.dart';
import 'package:hilmi/widgets/auth/legal_layout.dart';

/// 登录/注册校验等提示弹窗（样式与 EULA 弹层一致：米黄底 + 黑边）。
Future<void> showAuthNoticeDialog(
  BuildContext context, {
  required String message,
  String title = 'Notice',
}) async {
  final s = MediaQuery.sizeOf(context).width / LegalLayout.designWidth;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300 * s,
            padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 16 * s),
            decoration: BoxDecoration(
              color: LegalLayout.cream,
              borderRadius: BorderRadius.circular(20 * s),
              border: Border.all(
                color: Colors.black,
                width: LegalLayout.borderWidth,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: LegalLayout.titleSize * s,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 12 * s),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: LegalLayout.bodySize * s,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 18 * s),
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: double.infinity,
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
                          'OK',
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
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 双按钮确认弹窗（米黄底 + 黑边）；确认返回 `true`，取消返回 `false`。
Future<bool> showAuthConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Cancel',
  String? confirmBackgroundAsset,
  String? cancelBackgroundAsset,
  bool barrierDismissible = true,
  double? actionButtonHeight,
}) async {
  final confirmBg = confirmBackgroundAsset ?? LegalAssets.btnConfirm;
  final s = MediaQuery.sizeOf(context).width / LegalLayout.designWidth;
  final buttonH = (actionButtonHeight ?? LegalLayout.confirmH) * s;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300 * s,
            padding: EdgeInsets.fromLTRB(20 * s, 20 * s, 20 * s, 16 * s),
            decoration: BoxDecoration(
              color: LegalLayout.cream,
              borderRadius: BorderRadius.circular(20 * s),
              border: Border.all(
                color: Colors.black,
                width: LegalLayout.borderWidth,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: LegalLayout.titleSize * s,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 12 * s),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: LegalLayout.bodySize * s,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 18 * s),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.of(dialogContext).pop(false),
                        behavior: HitTestBehavior.opaque,
                        child: cancelBackgroundAsset != null
                            ? SizedBox(
                                height: buttonH,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned.fill(
                                      child: Image.asset(
                                        cancelBackgroundAsset,
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                    Text(
                                      cancelLabel,
                                      style: TextStyle(
                                        fontSize:
                                            LegalLayout.confirmTextSize * s,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                height: buttonH,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(26 * s),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: LegalLayout.borderWidth,
                                  ),
                                ),
                                child: Text(
                                  cancelLabel,
                                  style: TextStyle(
                                    fontSize:
                                        LegalLayout.confirmTextSize * s,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.of(dialogContext).pop(true),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: buttonH,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  confirmBg,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Text(
                                confirmLabel,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      LegalLayout.confirmTextSize * s,
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
              ],
            ),
          ),
        ),
      );
    },
  );

  return result ?? false;
}
