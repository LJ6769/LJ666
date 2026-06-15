// 注册第二步：头像与简介完善。
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hilmi/constants/legal_documents.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/eula_service.dart';
import 'package:hilmi/models/signup_draft.dart';
import 'package:hilmi/utils/apple_sign_in_flow.dart';
import 'package:hilmi/utils/auth_error_message.dart';
import 'package:hilmi/utils/auth_routes.dart';
import 'package:hilmi/utils/gallery_media_picker.dart';
import 'package:hilmi/utils/keyboard_dismiss.dart';
import 'package:hilmi/widgets/auth/auth_notice_dialog.dart';
import 'package:hilmi/widgets/auth/legal_agreement_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupStep2Controller extends GetxController {
  SignupStep2Controller({required this.draft});

  final SignupDraft draft;

  final scrollController = ScrollController();
  final introController = TextEditingController();
  final introFocus = FocusNode();
  final introSectionKey = GlobalKey();
  final _galleryPicker = GalleryMediaPicker();
  final avatarPath = RxnString();
  final submitting = false.obs;
  double? stableSafeBottom;

  late final VoidCallback _introFocusListener = onIntroFocus;

  @override
  void onInit() {
    super.onInit();
    introFocus.addListener(_introFocusListener);
  }

  @override
  void onClose() {
    introFocus.removeListener(_introFocusListener);
    scrollController.dispose();
    introFocus.dispose();
    introController.dispose();
    super.onClose();
  }

  void captureStableSafeBottom(BuildContext context) {
    stableSafeBottom ??= MediaQuery.viewPaddingOf(context).bottom;
  }

  void blurIntro(BuildContext context) {
    if (introFocus.hasFocus) {
      introFocus.unfocus();
    }
    dismissKeyboard(context);
  }

  void onIntroFocus() {
    if (!introFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = introSectionKey.currentContext;
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
    if (avatarPath.value == null || avatarPath.value!.isEmpty) {
      missing.add('Avatar');
    }
    if (introController.text.trim().isEmpty) missing.add('Intro');
    return missing;
  }

  String emptyFieldMessage(String field) {
    if (field == 'Avatar') return 'Please select Avatar';
    return 'Please enter $field';
  }

  Future<void> showEmptyFieldsDialog(
    BuildContext context,
    List<String> fields,
  ) {
    final message = fields.length == 1
        ? emptyFieldMessage(fields.first)
        : fields.map(emptyFieldMessage).join('\n');
    return showAuthNoticeDialog(context, message: message);
  }

  Future<ImageSource?> chooseAvatarSource(BuildContext context, double s) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFFFEFAEF),
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

  Future<void> pickAvatar(BuildContext context, double s) async {
    final source = await chooseAvatarSource(context, s);
    if (source == null || !context.mounted) return;

    final files = await _galleryPicker.pickImages(limit: 1, source: source);
    if (!context.mounted) return;
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

    if (!context.mounted) return;
    avatarPath.value = files.first.path;
  }

  void popToLogin(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AuthRoutes.login,
    );
  }

  Future<void> onAppleSignUp(BuildContext context) async {
    if (submitting.value) return;
    blurIntro(context);

    if (!isAppleSignInSupported) {
      await showAuthNoticeDialog(
        context,
        message: 'Sign up with Apple is only available on iPhone, iPad, and Mac.',
      );
      return;
    }

    submitting.value = true;
    try {
      final ok = await runAppleSignInFlow(context, includeSignupEula: true);
      if (!context.mounted || !ok) return;
      popToLogin(context);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (context.mounted) submitting.value = false;
    }
  }

  Future<void> onSignUp(BuildContext context) async {
    if (submitting.value) return;
    blurIntro(context);

    final missing = missingFieldLabels();
    if (missing.isNotEmpty) {
      await showEmptyFieldsDialog(context, missing);
      if (context.mounted) blurIntro(context);
      return;
    }

    if (!context.mounted) return;

    submitting.value = true;

    var eulaAccepted =
        await EulaService.hasAcceptedSignup(email: draft.email);
    if (!eulaAccepted) {
      if (!context.mounted) return;
      final agreedEula = await LegalAgreementSheet.show(
        context,
        title: 'EULA',
        content: LegalDocuments.userAgreement,
      );
      if (!context.mounted) return;
      blurIntro(context);
      if (!agreedEula) {
        if (context.mounted) submitting.value = false;
        return;
      }
      eulaAccepted = true;
    }

    if (!context.mounted) {
      submitting.value = false;
      return;
    }
    try {
      await AuthService.completeSignUp(
        email: draft.email,
        password: draft.password,
        displayName: draft.name,
        bio: introController.text.trim(),
        avatarLocalPath: avatarPath.value,
        eulaAccepted: eulaAccepted,
      );
      if (!context.mounted) return;
      await showAuthNoticeDialog(
        context,
        message: 'Account created. Please sign in.',
      );
      if (!context.mounted) return;
      popToLogin(context);
    } on AuthException catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(context, message: messageFromAuthError(error));
    } on StateError catch (error) {
      if (!context.mounted) return;
      final msg = messageFromAuthError(error);
      await showAuthNoticeDialog(context, message: msg);
      if (!context.mounted) return;
      popToLogin(context);
    } catch (error) {
      if (!context.mounted) return;
      await showAuthNoticeDialog(context, message: messageFromAuthError(error));
    } finally {
      if (context.mounted) submitting.value = false;
    }
  }
}
