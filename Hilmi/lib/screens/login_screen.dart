import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hilmi/core/eula_service.dart';
import 'package:hilmi/utils/open_signup_screen.dart';
import 'package:hilmi/widgets/auth/auth_legal_footer.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';
import 'package:hilmi/widgets/auth/login_assets.dart';
import 'package:hilmi/utils/apple_sign_in_flow.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/login_layout.dart';

/// 登录页（对齐设计稿整屏示例）。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const _cream = Color(0xFFFEFAEF);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / LoginLayout.designWidth;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  List<String> _missingFieldLabels() {
    final missing = <String>[];
    if (_emailController.text.trim().isEmpty) missing.add('Email');
    if (_passwordController.text.isEmpty) missing.add('Password');
    return missing;
  }

  Future<void> _showEmptyFieldsDialog(List<String> fields) {
    final message = fields.length == 1
        ? 'Please enter ${fields.first}'
        : 'Please enter ${fields.join(', ')}';
    return showAuthNoticeDialog(context, message: message);
  }

  Future<void> _onAppleSignIn() async {
    if (_submitting) return;
    dismissKeyboard(context);

    if (!isAppleSignInSupported) {
      await showAuthNoticeDialog(
        context,
        message: 'Sign in with Apple is only available on iPhone, iPad, and Mac.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await runAppleSignInFlow(context);
      if (!mounted || !ok) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onSignIn() async {
    if (_submitting) return;
    dismissKeyboard(context);

    final missing = _missingFieldLabels();
    if (missing.isNotEmpty) {
      await _showEmptyFieldsDialog(missing);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _submitting = true);

    if (!mounted) return;
    if (!await EulaService.hasAcceptedLogin(email: email)) {
      if (!mounted) return;
      final agreedEula = await LegalAgreementSheet.show(
        context,
        title: 'EULA',
        content: LegalDocuments.userAgreement,
      );
      if (!agreedEula || !mounted) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
    }

    if (!mounted) {
      setState(() => _submitting = false);
      return;
    }
    try {
      await AuthService.signInWithEmail(email: email, password: password);
      if (!mounted) return;
      await EulaService.recordLoginAcceptance();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(context, message: messageFromAuthError(error));
    } catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(context, message: messageFromAuthError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final safeBottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final sheetTop = LoginLayout.sheetTop * s;
    // 杯底骑在红白分界线上（仅底座探入奶油区，杯身留在红色区域）
    final mascotTop = sheetTop -
        LoginLayout.mascotH * s +
        LoginLayout.mascotIntoSheet * s;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: LoginScreen._cream,
        resizeToAvoidBottomInset: false,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: sheetTop + 40 * s,
              child: Image.asset(
                LoginAssets.headerBg,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),

            Positioned(
              top: sheetTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: LoginScreen._cream,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28 * s),
                  ),
                ),
                child: SizedBox.expand(
                  child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: LoginLayout.formPadH * s),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bottomBlockH = (LoginLayout.signInH +
                              LoginLayout.signInToLegalGap +
                              LoginLayout.legalBlockH) *
                          s;
                      final bottomPad =
                          LoginLayout.formPadBottom * s + safeBottomInset;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned(
                            top: LoginLayout.formPadTop * s,
                            left: 0,
                            right: 0,
                            bottom: bottomBlockH + bottomPad,
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _FieldLabel(
                                    scale: s,
                                    asset: LoginAssets.labelEmail,
                                  ),
                                  SizedBox(height: 8 * s),
                                  _AuthTextField(
                                    scale: s,
                                    height: LoginLayout.fieldH * s,
                                    controller: _emailController,
                                    hintText: 'Your Email',
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                  ),
                                  SizedBox(height: 16 * s),
                                  _FieldLabel(
                                    scale: s,
                                    asset: LoginAssets.labelPassword,
                                  ),
                                  SizedBox(height: 8 * s),
                                  _AuthTextField(
                                    scale: s,
                                    height: LoginLayout.fieldH * s,
                                    controller: _passwordController,
                                    hintText: 'Your Password',
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    suffix: GestureDetector(
                                      onTap: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      child: Image.asset(
                                        _obscurePassword
                                            ? LoginAssets.icEyeOff
                                            : LoginAssets.icEye,
                                        width: LoginLayout.eyeSize * s,
                                        height: LoginLayout.eyeSize * s,
                                      ),
                                    ),
                                    onSubmitted: (_) => _onSignIn(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: bottomPad,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _submitting ? null : _onSignIn,
                                        behavior: HitTestBehavior.opaque,
                                        child: Opacity(
                                          opacity: _submitting ? 0.65 : 1,
                                          child: SizedBox(
                                            height: LoginLayout.signInH * s,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Positioned.fill(
                                                  child: Image.asset(
                                                    LoginAssets.btnSignIn,
                                                    fit: BoxFit.fill,
                                                  ),
                                                ),
                                                if (_submitting)
                                                  SizedBox(
                                                    width: 22 * s,
                                                    height: 22 * s,
                                                    child: const CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                else
                                                  Text(
                                                    'Sign in',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16 * s,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10 * s),
                                    GestureDetector(
                                      onTap: _submitting ? null : _onAppleSignIn,
                                      child: Image.asset(
                                        LoginAssets.btnApple,
                                        width: LoginLayout.appleW * s,
                                        height: LoginLayout.appleH * s,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: LoginLayout.signInToLegalGap * s,
                                ),
                                AuthLegalFooter(scale: s),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                ),
              ),
            ),

            Positioned(
              left: LoginLayout.mascotLeft * s,
              top: mascotTop,
              child: Image.asset(
                LoginAssets.mascot,
                width: LoginLayout.mascotW * s,
                height: LoginLayout.mascotH * s,
                fit: BoxFit.contain,
              ),
            ),

            Positioned(
              left: LoginLayout.titleLeft * s,
              top: LoginLayout.titleTop * s,
              width: LoginLayout.titleW * s,
              height: LoginLayout.titleH * s,
              child: Image.asset(
                LoginAssets.titleWelcome,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),

            Positioned(
              top: topInset + LoginLayout.backTopBelowSafe * s,
              left: LoginLayout.backLeft * s,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  LoginAssets.btnBack,
                  width: LoginLayout.backSize * s,
                  height: LoginLayout.backSize * s,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Positioned(
              top: topInset + LoginLayout.signUpTopBelowSafe * s,
              right: LoginLayout.signUpRight * s,
              child: GestureDetector(
                onTap: () => openSignupScreen(context),
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  LoginAssets.btnSignUp,
                  width: LoginLayout.signUpW * s,
                  height: LoginLayout.signUpH * s,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.scale, required this.asset});

  final double scale;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        asset,
        height: LoginLayout.labelH * scale,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.scale,
    required this.height,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.suffix,
    this.onSubmitted,
  });

  final double scale;
  final double height;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.black, width: 2.5),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 14 * s),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onTapOutside: (_) => dismissKeyboard(context),
        onSubmitted: (value) {
          dismissKeyboard(context);
          onSubmitted?.call(value);
        },
        style: TextStyle(
          fontSize: 15 * s,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 15 * s,
            fontWeight: FontWeight.w700,
            color: Colors.black.withValues(alpha: 0.35),
          ),
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(left: 6 * s),
                  child: suffix,
                ),
          suffixIconConstraints: BoxConstraints(
            minWidth: LoginLayout.eyeSize * s,
            minHeight: LoginLayout.eyeSize * s,
          ),
        ),
      ),
    );
  }
}
