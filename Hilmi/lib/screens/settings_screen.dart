// 设置页：关注、黑名单、协议、反馈、登出。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/controllers/settings_controller.dart';
import 'package:hilmi/core/getx/getx_screen.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/open_blacklist_list.dart';
import 'package:hilmi/utils/open_follow_list.dart';
import 'package:hilmi/utils/open_followers_list.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';
import 'package:hilmi/widgets/settings/feedback_dialog.dart';
import 'package:hilmi/widgets/settings/settings_assets.dart';

/// 设置页（Mine 右上角 Settings）。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _designWidth = 375.0;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / _designWidth;

  @override
  Widget build(BuildContext context) {
    return GetxScreen<SettingsController>(
      create: SettingsController.new,
      builder: (c) => Obx(
        () => _SettingsBody(
          c: c,
          scaleOf: _s,
          cacheSizeLabel: c.cacheSizeLabel.value,
          clearingCache: c.clearingCache.value,
          deletingAccount: c.deletingAccount.value,
          loggingOut: c.loggingOut.value,
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.c,
    required this.scaleOf,
    required this.cacheSizeLabel,
    required this.clearingCache,
    required this.deletingAccount,
    required this.loggingOut,
  });

  final SettingsController c;
  final double Function(BuildContext context) scaleOf;
  final String cacheSizeLabel;
  final bool clearingCache;
  final bool deletingAccount;
  final bool loggingOut;

  @override
  Widget build(BuildContext context) {
    final s = scaleOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final rows = <_SettingsRowData>[
      _SettingsRowData(
        icon: SettingsAssets.icFollow,
        title: 'Follow',
        onTap: () => openFollowListScreen(context),
      ),
      _SettingsRowData(
        icon: SettingsAssets.icFollowers,
        title: 'Followers',
        onTap: () => openFollowersListScreen(context),
      ),
      _SettingsRowData(
        icon: SettingsAssets.icTerms,
        title: 'Terms of use',
        onTap: () => LegalAgreementSheet.showReadOnly(
          context,
          title: 'Terms of use',
          content: LegalDocuments.userAgreement,
        ),
      ),
      _SettingsRowData(
        icon: SettingsAssets.icPrivacy,
        title: 'Privacy Policy',
        onTap: () => LegalAgreementSheet.showReadOnly(
          context,
          title: 'Privacy Policy',
          content: LegalDocuments.privacyPolicy,
        ),
      ),
      _SettingsRowData(
        icon: SettingsAssets.icBlacklist,
        title: 'Blacklist',
        onTap: () => openBlacklistListScreen(context),
      ),
      _SettingsRowData(
        icon: SettingsAssets.icFeedback,
        title: 'Feedback',
        onTap: () => FeedbackDialog.show(context),
      ),
      _SettingsRowData(
        icon: SettingsAssets.icVersion,
        title: 'Version',
        trailing: SettingsController.appVersionLabel,
      ),
      _SettingsRowData(
        icon: SettingsAssets.icClearCache,
        title: 'Clear cache',
        trailing: cacheSizeLabel,
        onTap: clearingCache ? null : () => c.onClearCache(context),
      ),
      _SettingsRowData(
        icon: SettingsAssets.icDeleteAccount,
        title: 'Delete Account',
        onTap: deletingAccount ? null : () => c.onDeleteAccount(context),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: splashBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: splashBackground,
        body: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20 * s,
                  topInset + 56 * s,
                  20 * s,
                  100 * s + bottomInset,
                ),
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) SizedBox(height: 10 * s),
                    _SettingsRow(scale: s, data: rows[i]),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: topInset + 8 * s,
              child: Text(
                'Settings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18 * s,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            AuthTopBarButton(
              top: topInset + 4 * s,
              left: 16 * s,
              size: 40 * s,
              asset: SettingsAssets.btnBack,
              onTap: () => Navigator.of(context).pop(),
            ),
            if (deletingAccount)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.25),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD14D4D),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 20 * s,
              right: 20 * s,
              bottom: 16 * s + bottomInset,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = width / _LogoutButton.aspect;

                  return GestureDetector(
                    onTap: (loggingOut || deletingAccount)
                        ? null
                        : () => c.onLogout(context),
                    behavior: HitTestBehavior.opaque,
                    child: Opacity(
                      opacity: loggingOut ? 0.65 : 1,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              SettingsAssets.btnLogout,
                              width: width,
                              height: height,
                              fit: BoxFit.fill,
                            ),
                            if (loggingOut)
                              SizedBox(
                                width: 22 * s,
                                height: 22 * s,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton {
  _LogoutButton._();
  static const aspect = 1005 / 153;
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final String icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.scale, required this.data});

  final double scale;
  final _SettingsRowData data;

  static const _accent = Color(0xFFD14D4D);

  @override
  Widget build(BuildContext context) {
    final s = scale;
    const rowHeight = 56.0;

    return GestureDetector(
      onTap: data.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: rowHeight * s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              SettingsAssets.rowBg,
              fit: BoxFit.fill,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14 * s),
              child: Row(
                children: [
                  Image.asset(
                    data.icon,
                    width: 32 * s,
                    height: 32 * s,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Text(
                      data.title,
                      style: TextStyle(
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (data.trailing != null)
                    Text(
                      data.trailing!,
                      style: TextStyle(
                        fontSize: 15 * s,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
