// 注册第二步：头像与简介完善。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/controllers/signup_step2_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/models/signup_draft.dart';
import 'package:hilmi/widgets/auth/auth_fixed_footer.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/login_layout.dart';
import 'package:hilmi/widgets/auth/signup_assets.dart';
import 'package:hilmi/widgets/auth/signup_avatar_preview.dart';

/// 注册第二步：头像 + 简介（对齐设计稿）。
class SignupStep2Screen extends StatelessWidget {
  const SignupStep2Screen({super.key, required this.draft});

  final SignupDraft draft;

  static const _cream = Color(0xFFFEFAEF);

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / LoginLayout.designWidth;

  @override
  Widget build(BuildContext context) {
    return GetxScreen<SignupStep2Controller>(
      create: () => SignupStep2Controller(draft: draft),
      builder: (c) => _SignupStep2Body(c: c, scaleOf: _s),
    );
  }
}

class _SignupStep2Body extends StatelessWidget {
  const _SignupStep2Body({required this.c, required this.scaleOf});

  final SignupStep2Controller c;
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
    final avatarSize = LoginLayout.avatarSize * s;
    final cameraSize = LoginLayout.avatarCameraSize * s;

    return PopScope(
      canPop: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: SignupStep2Screen._cream,
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
                  color: SignupStep2Screen._cream,
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
                                    _FieldLabel(
                                      scale: s,
                                      asset: SignupAssets.labelAvatar,
                                    ),
                                    SizedBox(height: 10 * s),
                                    Center(
                                      child: GestureDetector(
                                        onTap: () => c.pickAvatar(context, s),
                                        behavior: HitTestBehavior.opaque,
                                        child: SizedBox(
                                          width: avatarSize,
                                          height: avatarSize,
                                          child: Obx(
                                            () {
                                              final avatarPath = c.avatarPath.value;
                                              return Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  if (avatarPath != null)
                                                    SignupAvatarPreview(
                                                      filePath: avatarPath,
                                                      size: avatarSize,
                                                      borderRadius: 24 * s,
                                                      placeholder:
                                                          _AvatarPlaceholder(
                                                        size: avatarSize * 0.88,
                                                      ),
                                                    )
                                                  else
                                                    _AvatarPlaceholder(
                                                      size: avatarSize * 0.88,
                                                    ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Image.asset(
                                                      SignupAssets.icCamera,
                                                      width: cameraSize,
                                                      height: cameraSize,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 22 * s),
                                    Column(
                                      key: c.introSectionKey,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _FieldLabel(
                                          scale: s,
                                          asset: SignupAssets.labelIntro,
                                        ),
                                        SizedBox(height: 8 * s),
                                        Obx(
                                          () => Container(
                                            height: LoginLayout.introFieldH * s,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14 * s,
                                              vertical: 12 * s,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14 * s),
                                              border: Border.all(
                                                color: Colors.black,
                                                width: 2.5,
                                              ),
                                            ),
                                            child: TextField(
                                              controller: c.introController,
                                              focusNode: c.introFocus,
                                              readOnly: c.submitting.value,
                                              onTapOutside: (_) =>
                                                  c.blurIntro(context),
                                              onEditingComplete: () =>
                                                  c.blurIntro(context),
                                              onSubmitted: (_) =>
                                                  c.blurIntro(context),
                                              textInputAction:
                                                  TextInputAction.done,
                                              scrollPadding: EdgeInsets.only(
                                                bottom: fieldScrollPad,
                                              ),
                                              maxLines: null,
                                              expands: true,
                                              textAlignVertical:
                                                  TextAlignVertical.top,
                                              style: TextStyle(
                                                fontSize: 15 * s,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black,
                                                height: 1.35,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                hintText:
                                                    'Briefly introduce yourself...',
                                                hintStyle: TextStyle(
                                                  fontSize: 15 * s,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black
                                                      .withValues(alpha: 0.35),
                                                  height: 1.35,
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
                            ...AuthFixedFooterLayers.build(
                              scale: s,
                              safeBottomInset: safeBottomInset,
                              keyboardVisible: keyboardUp,
                              actionRow: Obx(
                                () {
                                  final submitting = c.submitting.value;
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Listener(
                                          behavior: HitTestBehavior.opaque,
                                          onPointerDown: (_) =>
                                              c.blurIntro(context),
                                          child: GestureDetector(
                                            onTap: submitting
                                                ? null
                                                : () => c.onSignUp(context),
                                            behavior: HitTestBehavior.opaque,
                                            child: Opacity(
                                              opacity: submitting ? 0.65 : 1,
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
                                                    if (submitting)
                                                      SizedBox(
                                                        width: 22 * s,
                                                        height: 22 * s,
                                                        child:
                                                            const CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    else
                                                      Text(
                                                        'Sign up',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16 * s,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10 * s),
                                      GestureDetector(
                                        onTap: submitting
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
              onTap: () => Navigator.of(context).pop(),
            ),
            AuthTopBarButton(
              top: topInset + LoginLayout.signUpTopBelowSafe * s,
              right: LoginLayout.signUpRight * s,
              width: LoginLayout.signUpW * s,
              height: LoginLayout.signUpH * s,
              asset: SignupAssets.btnSignIn,
              onTap: () => c.popToLogin(context),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        SignupAssets.avatarPlaceholder,
        width: size,
        height: size,
        fit: BoxFit.contain,
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
