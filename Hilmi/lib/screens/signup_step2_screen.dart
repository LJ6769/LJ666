import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hilmi/core/eula_service.dart';
import 'package:hilmi/models/signup_draft.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/apple_sign_in_flow.dart';
import 'package:hilmi/utils/auth_routes.dart';
import 'package:hilmi/utils/gallery_media_picker.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_fixed_footer.dart';
import 'package:hilmi/widgets/auth/auth_top_bar_button.dart';
import 'package:hilmi/widgets/auth/login_layout.dart';
import 'package:hilmi/widgets/auth/signup_assets.dart';
import 'package:hilmi/widgets/auth/signup_avatar_preview.dart';
import 'package:image_picker/image_picker.dart';

/// 注册第二步：头像 + 简介（对齐设计稿）。
class SignupStep2Screen extends StatefulWidget {
  const SignupStep2Screen({super.key, required this.draft});

  final SignupDraft draft;

  static const _cream = Color(0xFFFEFAEF);

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  final _scrollController = ScrollController();
  final _introController = TextEditingController();
  final _introFocus = FocusNode();
  final _introSectionKey = GlobalKey();
  final _galleryPicker = GalleryMediaPicker();
  String? _avatarPath;
  bool _submitting = false;
  double? _stableSafeBottom;

  double _s(BuildContext context) =>
      MediaQuery.sizeOf(context).width / LoginLayout.designWidth;

  late final VoidCallback _introFocusListener = _onIntroFocus;

  @override
  void initState() {
    super.initState();
    _introFocus.addListener(_introFocusListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stableSafeBottom ??= MediaQuery.viewPaddingOf(context).bottom;
  }

  void _blurIntro() {
    if (_introFocus.hasFocus) {
      _introFocus.unfocus();
    }
    dismissKeyboard(context);
  }

  void _onIntroFocus() {
    if (!_introFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sectionContext = _introSectionKey.currentContext;
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
    _introFocus.removeListener(_introFocusListener);
    _scrollController.dispose();
    _introFocus.dispose();
    _introController.dispose();
    super.dispose();
  }

  List<String> _missingFieldLabels() {
    final missing = <String>[];
    if (_avatarPath == null || _avatarPath!.isEmpty) missing.add('Avatar');
    if (_introController.text.trim().isEmpty) missing.add('Intro');
    return missing;
  }

  String _emptyFieldMessage(String field) {
    if (field == 'Avatar') return 'Please select Avatar';
    return 'Please enter $field';
  }

  Future<void> _showEmptyFieldsDialog(List<String> fields) {
    final message = fields.length == 1
        ? _emptyFieldMessage(fields.first)
        : fields.map(_emptyFieldMessage).join('\n');
    return showAuthNoticeDialog(context, message: message);
  }

  Future<ImageSource?> _chooseAvatarSource() async {
    final s = _s(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: SignupStep2Screen._cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16 * s)),
        side: const BorderSide(color: Colors.black, width: 2),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                'Photo Library',
                style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(
                'Camera',
                style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w700),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            SizedBox(height: 8 * s),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final source = await _chooseAvatarSource();
    if (source == null || !mounted) return;

    final files = await _galleryPicker.pickImages(limit: 1, source: source);
    if (!mounted) return;
    if (files == null) {
      await showAuthNoticeDialog(
        context,
        message: source == ImageSource.camera
            ? 'Camera access is required.'
            : 'Photo library access is required.',
      );
      return;
    }
    if (files.isEmpty) return;

    if (!mounted) return;
    setState(() => _avatarPath = files.first.path);
  }

  void _popToLogin() {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AuthRoutes.login,
    );
  }

  Future<void> _onAppleSignUp() async {
    if (_submitting) return;
    _blurIntro();

    if (!isAppleSignInSupported) {
      await showAuthNoticeDialog(
        context,
        message: 'Sign up with Apple is only available on iPhone, iPad, and Mac.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final ok = await runAppleSignInFlow(context, includeSignupEula: true);
      if (!mounted || !ok) return;
      _popToLogin();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onSignUp() async {
    if (_submitting) return;
    _blurIntro();

    final missing = _missingFieldLabels();
    if (missing.isNotEmpty) {
      await _showEmptyFieldsDialog(missing);
      if (mounted) _blurIntro();
      return;
    }

    if (!mounted) return;

    setState(() => _submitting = true);

    var eulaAccepted =
        await EulaService.hasAcceptedSignup(email: widget.draft.email);
    if (!eulaAccepted) {
      if (!mounted) return;
      final agreedEula = await LegalAgreementSheet.show(
        context,
        title: 'EULA',
        content: LegalDocuments.userAgreement,
      );
      if (!mounted) return;
      _blurIntro();
      if (!agreedEula) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
      eulaAccepted = true;
    }

    if (!mounted) {
      setState(() => _submitting = false);
      return;
    }
    try {
      await AuthService.completeSignUp(
        email: widget.draft.email,
        password: widget.draft.password,
        displayName: widget.draft.name,
        bio: _introController.text.trim(),
        avatarLocalPath: _avatarPath,
        eulaAccepted: eulaAccepted,
      );
      if (!mounted) return;
      await showAuthNoticeDialog(
        context,
        message: 'Account created. Please sign in.',
      );
      if (!mounted) return;
      _popToLogin();
    } on AuthException catch (error) {
      if (!mounted) return;
      await showAuthNoticeDialog(context, message: messageFromAuthError(error));
    } on StateError catch (error) {
      if (!mounted) return;
      final msg = messageFromAuthError(error);
      await showAuthNoticeDialog(context, message: msg);
      if (!mounted) return;
      _popToLogin();
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
    final safeBottomInset =
        _stableSafeBottom ?? MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final sheetTop = LoginLayout.sheetTop * s;
    final mascotTop = sheetTop -
        LoginLayout.mascotH * s +
        LoginLayout.mascotIntoSheet * s;
    final avatarSize = LoginLayout.avatarSize * s;
    final cameraSize = LoginLayout.avatarCameraSize * s;

    final actionRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _blurIntro(),
            child: GestureDetector(
              onTap: _submitting ? null : _onSignUp,
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
                          SignupAssets.btnNext,
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
                          'Sign up',
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
        ),
        SizedBox(width: 10 * s),
        GestureDetector(
          onTap: _submitting ? null : _onAppleSignUp,
          child: Image.asset(
            SignupAssets.btnApple,
            width: LoginLayout.appleW * s,
            height: LoginLayout.appleH * s,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );

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
                                    _FieldLabel(
                                      scale: s,
                                      asset: SignupAssets.labelAvatar,
                                    ),
                                    SizedBox(height: 10 * s),
                                    Center(
                                      child: GestureDetector(
                                        onTap: _pickAvatar,
                                        behavior: HitTestBehavior.opaque,
                                        child: SizedBox(
                                          width: avatarSize,
                                          height: avatarSize,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              if (_avatarPath != null)
                                                SignupAvatarPreview(
                                                  filePath: _avatarPath!,
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
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 22 * s),
                                    Column(
                                      key: _introSectionKey,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _FieldLabel(
                                          scale: s,
                                          asset: SignupAssets.labelIntro,
                                        ),
                                        SizedBox(height: 8 * s),
                                        Container(
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
                                            controller: _introController,
                                            focusNode: _introFocus,
                                            readOnly: _submitting,
                                            onTapOutside: (_) => _blurIntro(),
                                            onEditingComplete: _blurIntro,
                                            onSubmitted: (_) => _blurIntro(),
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
              onTap: () => Navigator.of(context).pop(),
            ),
            AuthTopBarButton(
              top: topInset + LoginLayout.signUpTopBelowSafe * s,
              right: LoginLayout.signUpRight * s,
              width: LoginLayout.signUpW * s,
              height: LoginLayout.signUpH * s,
              asset: SignupAssets.btnSignIn,
              onTap: _popToLogin,
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
