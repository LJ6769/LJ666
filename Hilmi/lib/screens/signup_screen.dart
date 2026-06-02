import 'package:flutter/material.dart';
import 'package:hilmi/utils/apple_sign_in_flow.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/models/signup_draft.dart';
import 'package:hilmi/utils/auth_routes.dart';
import 'package:hilmi/screens/signup_step2_screen.dart';
import 'package:hilmi/widgets/auth/auth_fixed_footer.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/login_layout.dart';
import 'package:hilmi/widgets/auth/signup_assets.dart';

/// 注册页（Create Account，对齐设计稿）。
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static const _cream = Color(0xFFFEFAEF);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _emailSectionKey = GlobalKey();
  final _passwordSectionKey = GlobalKey();
  final _nameSectionKey = GlobalKey();
  bool _obscurePassword = true;
  bool _appleSigningUp = false;
  double? _stableSafeBottom;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / LoginLayout.designWidth;

  @override
  void initState() {
    super.initState();
    for (final node in [_emailFocus, _passwordFocus, _nameFocus]) {
      node.addListener(() => _onFieldFocus(node));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stableSafeBottom ??= MediaQuery.viewPaddingOf(context).bottom;
  }

  void _onFieldFocus(FocusNode node) {
    if (!node.hasFocus) return;
    final GlobalKey key;
    if (node == _emailFocus) {
      key = _emailSectionKey;
    } else if (node == _passwordFocus) {
      key = _passwordSectionKey;
    } else {
      key = _nameSectionKey;
    }
    _scrollFieldIntoView(key);
  }

  void _scrollFieldIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext = key.currentContext;
      if (sectionContext == null) return;
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  List<String> _missingFieldLabels() {
    final missing = <String>[];
    if (_emailController.text.trim().isEmpty) missing.add('Email');
    if (_passwordController.text.isEmpty) missing.add('Password');
    if (_nameController.text.trim().isEmpty) missing.add('Name');
    return missing;
  }

  Future<void> _showEmptyFieldsDialog(List<String> fields) {
    final message = fields.length == 1
        ? 'Please enter ${fields.first}'
        : 'Please enter ${fields.join(', ')}';
    return showAuthNoticeDialog(context, message: message);
  }

  Future<void> _onNext() async {
    dismissKeyboard(context);

    final missing = _missingFieldLabels();
    if (missing.isNotEmpty) {
      await _showEmptyFieldsDialog(missing);
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (password.length < 6) {
      await showAuthNoticeDialog(
        context,
        message: 'Password must be at least 6 characters',
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: AuthRoutes.signupStep2),
        builder: (_) => SignupStep2Screen(
          draft: SignupDraft(
            name: name,
            email: email,
            password: password,
          ),
        ),
      ),
    );
    // 注册成功时 Step2 会 popUntil 登录页，此处不再 pop(true) 以免跳过登录。
  }

  Future<void> _onAppleSignUp() async {
    if (_appleSigningUp) return;
    dismissKeyboard(context);

    if (!isAppleSignInSupported) {
      await showAuthNoticeDialog(
        context,
        message: 'Sign up with Apple is only available on iPhone, iPad, and Mac.',
      );
      return;
    }

    setState(() => _appleSigningUp = true);
    try {
      final ok = await runAppleSignInFlow(context, includeSignupEula: true);
      if (!mounted || !ok) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _appleSigningUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final safeBottomInset =
        _stableSafeBottom ?? MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final sheetTop = LoginLayout.sheetTop * s;
    final mascotTop = sheetTop -
        LoginLayout.mascotH * s +
        LoginLayout.mascotIntoSheet * s;

    final actionRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _onNext,
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
          onTap: _appleSigningUp ? null : _onAppleSignUp,
          child: Image.asset(
            SignupAssets.btnApple,
            width: LoginLayout.appleW * s,
            height: LoginLayout.appleH * s,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );

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
                                controller: _scrollController,
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
                                      sectionKey: _emailSectionKey,
                                      scale: s,
                                      labelAsset: SignupAssets.icEmail,
                                      child: _AuthTextField(
                                        scale: s,
                                        height: LoginLayout.fieldH * s,
                                        controller: _emailController,
                                        focusNode: _emailFocus,
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
                                      sectionKey: _passwordSectionKey,
                                      scale: s,
                                      labelAsset: SignupAssets.icPassword,
                                      child: _AuthTextField(
                                        scale: s,
                                        height: LoginLayout.fieldH * s,
                                        controller: _passwordController,
                                        focusNode: _passwordFocus,
                                        hintText: 'Your Password',
                                        scrollPadding: fieldScrollPad,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.next,
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
                                                ? SignupAssets.icEyeOff
                                                : SignupAssets.icEye,
                                            width: LoginLayout.eyeSize * s,
                                            height: LoginLayout.eyeSize * s,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 16 * s),
                                    _SignupFieldSection(
                                      sectionKey: _nameSectionKey,
                                      scale: s,
                                      labelAsset: SignupAssets.icName,
                                      child: _AuthTextField(
                                        scale: s,
                                        height: LoginLayout.fieldH * s,
                                        controller: _nameController,
                                        focusNode: _nameFocus,
                                        hintText: 'Your Name',
                                        scrollPadding: fieldScrollPad,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _onNext(),
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
                              actionRow: actionRow,
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
