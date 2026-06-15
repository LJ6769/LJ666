// 登录/注册底部可点击协议与隐私政策文案。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';

/// 登录/注册页底部协议文案（可点击 User Agreement / Privacy Policy）。
class AuthLegalFooter extends StatefulWidget {
  const AuthLegalFooter({super.key, required this.scale});

  final double scale;

  @override
  State<AuthLegalFooter> createState() => _AuthLegalFooterState();
}

class _AuthLegalFooterState extends State<AuthLegalFooter> {
  late final TapGestureRecognizer _userAgreementRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _userAgreementRecognizer = TapGestureRecognizer()..onTap = _onUserAgreement;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _onPrivacyPolicy;
  }

  @override
  void dispose() {
    _userAgreementRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _onUserAgreement() {
    LegalAgreementSheet.showReadOnly(
      context,
      title: 'User Agreement',
      content: LegalDocuments.userAgreement,
    );
  }

  void _onPrivacyPolicy() {
    LegalAgreementSheet.showReadOnly(
      context,
      title: 'Privacy Policy',
      content: LegalDocuments.privacyPolicy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final baseStyle = TextStyle(
      fontSize: 10.5 * s,
      color: Colors.black.withValues(alpha: 0.45),
      height: 1.45,
    );
    final linkStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w800,
      color: Colors.black.withValues(alpha: 0.8),
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'By signing up, you agree to the '),
          TextSpan(
            text: 'User Agreement',
            style: linkStyle,
            recognizer: _userAgreementRecognizer,
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
