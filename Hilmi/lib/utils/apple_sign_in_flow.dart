// 调起 Apple 登录并完成 EULA（登录/注册共用）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/eula_service.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';
import 'package:hilmi/utils/auth_error_message.dart';

bool get isAppleSignInSupported => Platform.isIOS || Platform.isMacOS;

/// 调起 Apple 登录并完成 EULA（登录 / 注册流程共用）。
Future<bool> runAppleSignInFlow(
  BuildContext context, {
  bool includeSignupEula = false,
}) async {
  try {
    await AuthService.signInWithApple();
  } catch (error) {
    if (context.mounted) {
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    }
    return false;
  }

  if (!context.mounted) return false;

  await AuthService.loadCurrentProfile(forceRefresh: true);

  if (includeSignupEula &&
      !await EulaService.hasAcceptedSignupForCurrentUser()) {
    if (!context.mounted) return false;
    final agreedSignup = await LegalAgreementSheet.show(
      context,
      title: 'EULA',
      content: LegalDocuments.userAgreement,
    );
    if (!agreedSignup) {
      await AuthService.clearAuthSession();
      return false;
    }
    await EulaService.recordSignupAcceptance();
    if (!context.mounted) return false;
  }

  if (!await EulaService.hasAcceptedLoginForCurrentUser()) {
    if (!context.mounted) return false;
    final agreedLogin = await LegalAgreementSheet.show(
      context,
      title: 'EULA',
      content: LegalDocuments.userAgreement,
    );
    if (!agreedLogin) {
      await AuthService.clearAuthSession();
      return false;
    }
  }

  await EulaService.recordLoginAcceptance();
  return AuthService.isLoggedIn;
}
