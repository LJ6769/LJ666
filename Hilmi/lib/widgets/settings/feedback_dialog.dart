import 'package:flutter/material.dart';
import 'package:hilmi/widgets/auth/legal_layout.dart';
import 'package:hilmi/widgets/settings/settings_assets.dart';

/// 设置页 Feedback 输入弹窗（对齐设计稿）。
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key, required this.scale});

  final double scale;

  static const _designWidth = 375.0;
  static const _panelDesignWidth = 319.0;
  static const _panelDesignHeight = 248.0;

  static const submittedSuccessMessage =
      'We have received your feedback and will process it within 24 hours.';

  static Future<bool?> show(BuildContext context) async {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final result = await showDialog<bool?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: false,
      builder: (context) => FeedbackDialog(scale: scale),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(submittedSuccessMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return result;
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  double get _s => widget.scale;

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onCancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(false);
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your feedback'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final panelW = FeedbackDialog._panelDesignWidth * _s;
    final panelH = FeedbackDialog._panelDesignHeight * _s;
    final inputHeight = 96 * _s;
    final btnHeight = 40 * _s;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelW,
          height: panelH,
          decoration: BoxDecoration(
            color: LegalLayout.cream,
            borderRadius: BorderRadius.circular(20 * _s),
            border: Border.all(
              color: Colors.black,
              width: LegalLayout.borderWidth,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20 * _s, 18 * _s, 20 * _s, 16 * _s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Feedback',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: LegalLayout.titleSize * _s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12 * _s),
                SizedBox(
                  height: inputHeight,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: LegalLayout.bodySize * _s,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFFD14B4B),
                    decoration: InputDecoration(
                      hintText: 'Please enter...',
                      hintStyle: TextStyle(
                        color: const Color(0xFFBDBDBD),
                        fontSize: LegalLayout.bodySize * _s,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.all(12 * _s),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * _s),
                        borderSide: BorderSide(
                          color: Colors.black,
                          width: LegalLayout.borderWidth,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * _s),
                        borderSide: BorderSide(
                          color: Colors.black,
                          width: LegalLayout.borderWidth,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * _s),
                        borderSide: BorderSide(
                          color: Colors.black,
                          width: LegalLayout.borderWidth,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14 * _s),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _submitting ? null : _onCancel,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: btnHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  SettingsAssets.btnCancel,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: LegalLayout.confirmTextSize * _s,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10 * _s),
                    Expanded(
                      child: GestureDetector(
                        onTap: _submitting ? null : _onSubmit,
                        behavior: HitTestBehavior.opaque,
                        child: Opacity(
                          opacity: _submitting ? 0.65 : 1,
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
                                  'Submit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize:
                                        LegalLayout.confirmTextSize * _s,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
