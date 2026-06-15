// EULA 同意流程封装（注册与登录分次记录）。
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/data/eula_repository.dart';

/// EULA 同意（服务端分注册 / 登录两次；删号后重置）。
abstract final class EulaService {
  static const _repository = EulaRepository();

  /// 注册前：是否已在注册流程同意过。
  static Future<bool> hasAcceptedSignup({required String email}) async {
    if (!AppBootstrap.isReady) return false;
    return _repository.hasAcceptedSignupByEmail(email);
  }

  /// 登录前：是否已在登录流程同意过（与注册分开）。
  static Future<bool> hasAcceptedLogin({required String email}) async {
    if (!AppBootstrap.isReady) return false;
    return _repository.hasAcceptedLoginByEmail(email);
  }

  /// 登录成功后记录登录 EULA 同意。
  static Future<void> recordLoginAcceptance() async {
    if (!AuthService.isLoggedIn) return;
    await _repository.acceptEulaLogin();
  }

  /// 当前会话是否已同意注册 EULA（Apple 等无邮箱预检时用）。
  static Future<bool> hasAcceptedSignupForCurrentUser() async {
    final authUserId = AuthService.currentUser?.id;
    if (authUserId == null || authUserId.isEmpty) return false;
    return _repository.hasAcceptedSignupForAuthUser(authUserId);
  }

  /// 当前会话是否已同意登录 EULA。
  static Future<bool> hasAcceptedLoginForCurrentUser() async {
    final authUserId = AuthService.currentUser?.id;
    if (authUserId == null || authUserId.isEmpty) return false;
    return _repository.hasAcceptedLoginForAuthUser(authUserId);
  }

  /// 注册流程同意（Apple 注册成功后调用）。
  static Future<void> recordSignupAcceptance() async {
    if (!AuthService.isLoggedIn) return;
    await _repository.acceptEulaSignup();
  }
}
