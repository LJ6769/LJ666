/// 注册第一步收集的资料，传入第二步完善头像与简介。
class SignupDraft {
  const SignupDraft({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;
}
