import 'package:flutter/material.dart';
import 'package:hilmi/utils/open_login_screen.dart';
import 'package:hilmi/widgets/live_room/live_room_assets.dart';

/// 直播间举报弹窗（对齐设计稿：浅色面板 + 白底输入 + Cancel / Submit）。
class LiveReportSheet extends StatefulWidget {
  const LiveReportSheet({super.key, required this.scale});

  final double scale;

  static const _designWidth = 375.0;
  static const _panelDesignWidth = 319.0;
  static const _panelDesignHeight = 248.0;
  static const _panelColor = Color(0xFFFDF9ED);

  static const submittedSuccessMessage =
      'We have received your feedback and will process it within 24 hours.';

  /// [scaffoldMessenger] 建议在关闭底部弹层前缓存，避免 pop 后 context 失效无法提示。
  static Future<bool?> show(
    BuildContext context, {
    ScaffoldMessengerState? scaffoldMessenger,
  }) async {
    final messenger =
        scaffoldMessenger ?? ScaffoldMessenger.maybeOf(context);
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    final result = await showDialog<bool?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (dialogContext) => LiveReportSheet(scale: scale),
    );
    if (result == true) {
      _showSubmittedSnackBar(messenger);
    }
    return result;
  }

  static void _showSubmittedSnackBar(ScaffoldMessengerState? messenger) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(submittedSuccessMessage),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  State<LiveReportSheet> createState() => _LiveReportSheetState();
}

class _LiveReportSheetState extends State<LiveReportSheet> {
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
          content: Text('Please enter report details'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!await ensureLoggedIn(context, loginHint: 'Please sign in to submit a report')) {
      return;
    }
    if (!mounted) return;

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final panelW = LiveReportSheet._panelDesignWidth * _s;
    final panelH = LiveReportSheet._panelDesignHeight * _s;
    final inputHeight = 96 * _s;
    final btnHeight = 40 * _s;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelW,
          height: panelH,
          decoration: BoxDecoration(
            color: LiveReportSheet._panelColor,
            borderRadius: BorderRadius.circular(20 * _s),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20 * _s, 18 * _s, 20 * _s, 16 * _s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Report',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18 * _s,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
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
                      fontSize: 14 * _s,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: const Color(0xFFD14B4B),
                    decoration: InputDecoration(
                      hintText: 'Please enter...',
                      hintStyle: TextStyle(
                        color: const Color(0xFFBDBDBD),
                        fontSize: 14 * _s,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.all(12 * _s),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * _s),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * _s),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * _s),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 2,
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
                        onTap: _submitting ? null : _onSubmit,
                        child: Opacity(
                          opacity: _submitting ? 0.65 : 1,
                          child: _ReportSubmitButton(
                            scale: _s,
                            height: btnHeight,
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

class _ReportSubmitButton extends StatelessWidget {
  const _ReportSubmitButton({
    required this.scale,
    required this.height,
  });

  final double scale;
  final double height;

  static const _submitAspect = 420 / 123;

  @override
  Widget build(BuildContext context) {
    final width = height * _submitAspect;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Image.asset(
              LiveRoomAssets.reportBtnSubmit,
              fit: BoxFit.fill,
            ),
          ),
          Text(
            'Submit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
