import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/local_cache_service.dart';
import 'package:hilmi/splash_page.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';
import 'package:hilmi/core/home_shell.dart';
import 'package:hilmi/utils/logout_and_go_home.dart';
import 'package:hilmi/utils/open_follow_list.dart';
import 'package:hilmi/utils/open_blacklist_list.dart';
import 'package:hilmi/utils/open_followers_list.dart';
import 'package:hilmi/widgets/settings/feedback_dialog.dart';
import 'package:hilmi/widgets/settings/settings_assets.dart';

/// 设置页（Mine 右上角 Settings）。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const _designWidth = 375.0;
  static const _appVersionLabel = 'V1.0.0';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheSizeLabel = '—';
  bool _clearingCache = false;
  bool _loggingOut = false;
  bool _deletingAccount = false;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / SettingsScreen._designWidth;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final bytes = await LocalCacheService.estimateCacheBytes();
    if (!mounted) return;
    setState(() {
      _cacheSizeLabel = LocalCacheService.formatCacheSize(bytes);
    });
  }

  Future<void> _onClearCache() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    try {
      await LocalCacheService.clearAll();
      await _refreshCacheSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _onDeleteAccount() async {
    if (_deletingAccount) return;

    final confirmed = await showAuthConfirmDialog(
      context,
      title: 'Delete Account',
      message:
          'Deleting your account will erase all your data and information '
          'and cannot be undone. Confirm deletion?',
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
      confirmBackgroundAsset: SettingsAssets.btnConfirm,
      cancelBackgroundAsset: SettingsAssets.btnCancel,
      barrierDismissible: false,
      actionButtonHeight: 40,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await AuthService.deleteAccount();
      await LocalCacheService.clearAll();
      if (!mounted) return;
      HomeShell.goToDiscoverHome();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<void> _onLogout() async {
    if (_loggingOut) return;

    final confirmed = await showAuthConfirmDialog(
      context,
      title: 'Log out',
      message:
          'After logging out, you will need to log in again to use your account again. Are you sure to log out?',
      confirmLabel: 'Confirm',
      cancelLabel: 'Cancel',
      confirmBackgroundAsset: SettingsAssets.btnConfirm,
      cancelBackgroundAsset: SettingsAssets.btnCancel,
      barrierDismissible: false,
      actionButtonHeight: 40,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await logoutAndGoHome(context);
    } catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(
        context,
        message: messageFromAuthError(error),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s(context);
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
        trailing: SettingsScreen._appVersionLabel,
      ),
      _SettingsRowData(
        icon: SettingsAssets.icClearCache,
        title: 'Clear cache',
        trailing: _cacheSizeLabel,
        onTap: _clearingCache ? null : _onClearCache,
      ),
      _SettingsRowData(
        icon: SettingsAssets.icDeleteAccount,
        title: 'Delete Account',
        onTap: _deletingAccount ? null : _onDeleteAccount,
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
            if (_deletingAccount)
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
                    onTap: (_loggingOut || _deletingAccount) ? null : _onLogout,
                    behavior: HitTestBehavior.opaque,
                    child: Opacity(
                      opacity: _loggingOut ? 0.65 : 1,
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
                            if (_loggingOut)
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
