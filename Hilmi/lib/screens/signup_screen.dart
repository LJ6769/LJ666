// 注册第一步：Create Account 表单。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/signup_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_fixed_footer.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/login_layout.dart';
import 'package:hilmi/widgets/auth/signup_assets.dart';

/// 注册页（Create Account，对齐设计稿）。
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  static const _cream = Color(0xFFFEFAEF);

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / LoginLayout.designWidth;

  @override
  Widget build(BuildContext context) {
    return GetxScreen<SignupController>(
      create: () => SignupController(),
      builder: (c) => _SignupBody(c: c, scaleOf: _s),
    );
  }
}

class _SignupBody extends StatelessWidget {
  const _SignupBody({required this.c, required this.scaleOf});

  final SignupController c;
  final double Function(BuildContext context) scaleOf;

  @override
  Widget build(BuildContext context) {
    c.captureStableSafeBottom(context);

    final s = scaleOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final safeBottomInset =
        c.stableSafeBottom ?? MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final sheetTop = LoginLayout.sheetTop * s;
    final mascotTop = sheetTop -
        LoginLayout.mascotH * s +
        LoginLayout.mascotIntoSheet * s;

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: SignupScreen._cream,
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
                SignupAssets.headerBg,
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
                  color: SignupScreen._cream,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28 * s),
                  ),
                ),
                child: SizedBox.expand(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: LoginLayout.formPadH * s,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final keyboardUp = keyboardInset > 0;
                        final bottomBlockH =
                            AuthFixedFooterLayout.totalFooterHeight(scale: s);
                        final buttonBottom = LoginLayout.authFixedButtonBottom(
                          scale: s,
                          safeBottomInset: safeBottomInset,
                        );
                        final scrollAreaBottom =
                            LoginLayout.authFormScrollAreaBottom(
                          scale: s,
                          keyboardInset: keyboardInset,
                          fixedBottomBlockHeight: bottomBlockH,
                          fixedButtonBottom: buttonBottom,
                        );
                        final fieldScrollPad =
                            LoginLayout.authFieldScrollPadding(scale: s);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              top: LoginLayout.formPadTop * s,
                              left: 0,
                              right: 0,
                              bottom: scrollAreaBottom,
                              child: SingleChildScrollView(
                                controller: c.scrollController,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: ClampingScrollPhysics(),
                                ),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SignupFieldSection(
                                      sectionKey: c.emailSectionKey,
                                      scale: s,
                                      labelAsset: SignupAssets.icEmail,
                                      child: _AuthTextField(
                                        scale: s,
                                        height: LoginLayout.fieldH * s,
                                        controller: c.emailController,
                                        focusNode: c.emailFocus,
                                        hintText: 'Your Email',
                                        scrollPadding: fieldScrollPad,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.email,
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16 * s),
                                    _SignupFieldSection(
                                      sectionKey: c.passwordSectionKey,
                                      scale: s,
                                      labelAsset: SignupAssets.icPassword,
                                      child: Obx(
                                        () => _AuthTextField(
                                          scale: s,
                                          height: LoginLayout.fieldH * s,
                                          controller: c.passwordController,
                                          focusNode: c.passwordFocus,
                                          hintText: 'Your Password',
                                          scrollPadding: fieldScrollPad,
                                          obscureText: c.obscurePassword.value,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          suffix: GestureDetector(
                                            onTap: () => c.obscurePassword.value =
                                                !c.obscurePassword.value,
                                            child: Image.asset(
                                              c.obscurePassword.value
                                                  ? SignupAssets.icEyeOff
                                                  : SignupAssets.icEye,
                                              width: LoginLayout.eyeSize * s,
                                              height: LoginLayout.eyeSize * s,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 16 * s),
                                    _SignupFieldSection(
                                      sectionKey: c.nameSectionKey,
                                      scale: s,
                                      labelAsset: SignupAssets.icName,
                                      child: _AuthTextField(
                                        scale: s,
                                        height: LoginLayout.fieldH * s,
                                        controller: c.nameController,
                                        focusNode: c.nameFocus,
                                        hintText: 'Your Name',
                                        scrollPadding: fieldScrollPad,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => c.onNext(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ...AuthFixedFooterLayers.build(
                              scale: s,
                              safeBottomInset: safeBottomInset,
                              keyboardVisible: keyboardUp,
                              actionRow: Obx(
                                () {
                                  final appleSigningUp = c.appleSigningUp.value;
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => c.onNext(context),
                                          behavior: HitTestBehavior.opaque,
                                          child: SizedBox(
                                            height: LoginLayout.signInH * s,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Positioned.fill(
                                                  child: Image.asset(
                                                    SignupAssets.btnNext,
                                                    fit: BoxFit.fill,
                                                  ),
                                                ),
                                                Text(
                                                  'Next',
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
                                      SizedBox(width: 10 * s),
                                      GestureDetector(
                                        onTap: appleSigningUp
                                            ? null
                                            : () => c.onAppleSignUp(context),
                                        child: Image.asset(
                                          SignupAssets.btnApple,
                                          width: LoginLayout.appleW * s,
                                          height: LoginLayout.appleH * s,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  );
                                },
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
                SignupAssets.mascot,
                width: LoginLayout.mascotW * s,
                height: LoginLayout.mascotH * s,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: LoginLayout.titleLeft * s,
              top: LoginLayout.titleTop * s,
              width: 200 * s,
              height: LoginLayout.titleH * s,
              child: Image.asset(
                SignupAssets.titleCreateAccount,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
            AuthTopBarButton(
              top: topInset + LoginLayout.backTopBelowSafe * s,
              left: LoginLayout.backLeft * s,
              size: LoginLayout.backSize * s,
              asset: SignupAssets.btnBack,
              onTap: () => Navigator.of(context).pop(false),
            ),
            AuthTopBarButton(
              top: topInset + LoginLayout.signUpTopBelowSafe * s,
              right: LoginLayout.signUpRight * s,
              width: LoginLayout.signUpW * s,
              height: LoginLayout.signUpH * s,
              asset: SignupAssets.btnSignIn,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupFieldSection extends StatelessWidget {
  const _SignupFieldSection({
    required this.sectionKey,
    required this.scale,
    required this.labelAsset,
    required this.child,
  });

  final GlobalKey sectionKey;
  final double scale;
  final String labelAsset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            labelAsset,
            height: LoginLayout.labelH * scale,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: 8 * scale),
        child,
      ],
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.scale,
    required this.height,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.scrollPadding = 0,
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
  final FocusNode? focusNode;
  final double scrollPadding;
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
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        scrollPadding: EdgeInsets.only(bottom: scrollPadding),
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
