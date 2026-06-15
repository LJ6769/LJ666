// 注册第一步：Create Account 表单。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/models/signup_draft.dart';
import 'package:hilmi/screens/signup_step2_screen.dart';
import 'package:hilmi/utils/apple_sign_in_flow.dart';
import 'package:hilmi/utils/auth_routes.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';

class SignupController extends GetxController {
  final scrollController = ScrollController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  final nameFocus = FocusNode();
  final emailSectionKey = GlobalKey();
  final passwordSectionKey = GlobalKey();
  final nameSectionKey = GlobalKey();
  final obscurePassword = true.obs;
  final appleSigningUp = false.obs;
  double? stableSafeBottom;

  @override
  void onInit() {
    super.onInit();
    for (final node in [emailFocus, passwordFocus, nameFocus]) {
      node.addListener(() => onFieldFocus(node));
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    nameFocus.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void captureStableSafeBottom(BuildContext context) {
    stableSafeBottom ??= MediaQuery.viewPaddingOf(context).bottom;
  }

  void onFieldFocus(FocusNode node) {
    if (!node.hasFocus) return;
    final GlobalKey key;
    if (node == emailFocus) {
      key = emailSectionKey;
    } else if (node == passwordFocus) {
      key = passwordSectionKey;
    } else {
      key = nameSectionKey;
    }
    scrollFieldIntoView(key);
  }

  void scrollFieldIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  List<String> missingFieldLabels() {
    final missing = <String>[];
    if (emailController.text.trim().isEmpty) missing.add('Email');
    if (passwordController.text.isEmpty) missing.add('Password');
    if (nameController.text.trim().isEmpty) missing.add('Name');
    return missing;
  }

  Future<void> showEmptyFieldsDialog(
    BuildContext context,
    List<String> fields,
  ) {
    final message = fields.length == 1
        ? 'Please enter ${fields.first}'
        : 'Please enter ${fields.join(', ')}';
    return showAuthNoticeDialog(context, message: message);
  }

  Future<void> onNext(BuildContext context) async {
    dismissKeyboard(context);

    final missing = missingFieldLabels();
    if (missing.isNotEmpty) {
      await showEmptyFieldsDialog(context, missing);
      return;
    }

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

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

  Future<void> onAppleSignUp(BuildContext context) async {
    if (appleSigningUp.value) return;
    dismissKeyboard(context);

    if (!isAppleSignInSupported) {
      await showAuthNoticeDialog(
        context,
        message: 'Sign up with Apple is only available on iPhone, iPad, and Mac.',
      );
      return;
    }

    appleSigningUp.value = true;
    try {
      final ok = await runAppleSignInFlow(context, includeSignupEula: true);
      if (!context.mounted || !ok) return;
      Navigator.of(context).pop(true);
    } finally {
      if (context.mounted) appleSigningUp.value = false;
    }
  }
}
