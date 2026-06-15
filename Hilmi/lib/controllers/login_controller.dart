// 登录页：邮箱密码与 Apple 登录。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/eula_service.dart';
import 'package:hilmi/utils/apple_sign_in_flow.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final obscurePassword = true.obs;
  final submitting = false.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  List<String> missingFieldLabels() {
    final missing = <String>[];
    if (emailController.text.trim().isEmpty) missing.add('Email');
    if (passwordController.text.isEmpty) missing.add('Password');
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

  Future<void> onAppleSignIn(BuildContext context) async {
    if (submitting.value) return;
    dismissKeyboard(context);

    if (!isAppleSignInSupported) {
      await showAuthNoticeDialog(
        context,
        message: 'Sign in with Apple is only available on iPhone, iPad, and Mac.',
      );
      return;
    }

    submitting.value = true;
    try {
      final ok = await runAppleSignInFlow(context);
      if (!context.mounted || !ok) return;
      Navigator.of(context).pop(true);
    } finally {
      if (context.mounted) submitting.value = false;
    }
  }

  Future<void> onSignIn(BuildContext context) async {
    if (submitting.value) return;
    dismissKeyboard(context);

    final missing = missingFieldLabels();
    if (missing.isNotEmpty) {
      await showEmptyFieldsDialog(context, missing);
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;

    submitting.value = true;

    if (!context.mounted) return;
    if (!await EulaService.hasAcceptedLogin(email: email)) {
      if (!context.mounted) return;
      final agreedEula = await LegalAgreementSheet.show(
        context,
        title: 'EULA',
        content: LegalDocuments.userAgreement,
      );
      if (!agreedEula || !context.mounted) {
        if (context.mounted) submitting.value = false;
        return;
      }
    }

    if (!context.mounted) {
      submitting.value = false;
      return;
    }
    try {
      await AuthService.signInWithEmail(email: email, password: password);
      if (!context.mounted) return;
      await EulaService.recordLoginAcceptance();
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(context, message: messageFromAuthError(error));
    } catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(context, message: messageFromAuthError(error));
    } finally {
      if (context.mounted) submitting.value = false;
    }
  }
}
