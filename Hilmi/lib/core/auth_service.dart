import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/block_service.dart';
import 'package:hilmi/core/follow_service.dart';
import 'package:hilmi/core/hidden_conversations_service.dart';
import 'package:hilmi/core/like_service.dart';
import 'package:hilmi/core/pending_avatar_storage.dart';
import 'package:hilmi/data/eula_repository.dart';
import 'package:hilmi/data/auth_repository.dart';
import 'package:hilmi/models/user_profile.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:hilmi/services/user_storage_cleanup.dart';
import 'package:hilmi/utils/apple_auth_nonce.dart';
import 'package:hilmi/utils/storage_user_folder.dart';
import 'package:hilmi/utils/supabase_auth_errors.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:hilmi/widgets/common/cached_media_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth + public."User" 资料。
abstract final class AuthService {
  static const _authRepo = AuthRepository();

  static UserProfile? _cachedProfile;
  static Future<UserProfile?>? _profileLoadInFlight;

  /// 金币变动时通知顶栏等 UI（消费礼物、内购、建聊天室等）。
  static final ValueNotifier<int?> coinsNotifier = ValueNotifier<int?>(null);

  static GoTrueClient? get _auth => AppBootstrap.client?.auth;

  static SupabaseClient? get _client => AppBootstrap.client;

  static UserProfile? get cachedProfile => _cachedProfile;

  static bool get isLoggedIn {
    final session = _auth?.currentSession;
    return session != null && !session.isExpired;
  }

  static User? get currentUser => _auth?.currentUser;

  static Stream<AuthState> get onAuthStateChange {
    final auth = _auth;
    if (auth == null) return const Stream.empty();
    return auth.onAuthStateChange;
  }

  static Future<UserProfile?> loadCurrentProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProfile != null) return _cachedProfile;

    final inFlight = _profileLoadInFlight;
    if (inFlight != null) return inFlight;

    final future = _loadCurrentProfile();
    _profileLoadInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_profileLoadInFlight, future)) {
        _profileLoadInFlight = null;
      }
    }
  }

  static Future<UserProfile?> _loadCurrentProfile() async {
    final client = _client;
    final user = currentUser;
    if (client == null || user == null) {
      _cachedProfile = null;
      _publishCoins(null);
      return null;
    }

    try {
      final row = await _authRepo.findByAuthUserId(client, user.id);
      if (row == null) {
        _cachedProfile = null;
        _publishCoins(null);
        return null;
      }

      final avatarPath = row['avatar_path'] as String?;
      final previousPath = _cachedProfile?.avatarPath?.trim() ?? '';
      final nextPath = avatarPath?.trim() ?? '';
      final pathUnchanged =
          previousPath == nextPath && previousPath.isNotEmpty;

      String? avatarUrl = pathUnchanged ? _cachedProfile?.avatarUrl : null;
      if (nextPath.isNotEmpty) {
        if (!pathUnchanged ||
            avatarUrl == null ||
            avatarUrl.isEmpty ||
            !StorageMediaUrlResolver.isValidSignedMediaUrl(avatarUrl)) {
          avatarUrl = await StorageMediaUrlResolver.resolve(
            avatarPath,
            client: client,
          );
        }
      } else {
        avatarUrl = null;
      }

      final resolvedUrl = avatarUrl ?? '';
      _cachedProfile = UserProfile.fromJson(
        row,
        avatarUrl: resolvedUrl.isEmpty ? null : resolvedUrl,
      );
      FollowService.applyFromProfile(_cachedProfile);
      BlockService.applyFromProfile(_cachedProfile);
      LikeService.applyFromProfile(_cachedProfile);
      _publishCoins(_cachedProfile!.coins);
      return _cachedProfile;
    } on PostgrestException catch (error, stack) {
      if (isJwtClockSkewError(error)) {
        await _recoverFromJwtClockSkew();
        return null;
      }
      debugPrint('[AuthService] loadCurrentProfile: $error');
      debugPrint('$stack');
      return null;
    } catch (error, stack) {
      if (isJwtClockSkewError(error)) {
        await _recoverFromJwtClockSkew();
        return null;
      }
      debugPrint('[AuthService] loadCurrentProfile: $error');
      debugPrint('$stack');
      return null;
    }
  }

  /// 本机时间超前导致 JWT 无效：清除本地会话，避免反复 401。
  static Future<void> _recoverFromJwtClockSkew() async {
    debugPrint(
      '[AuthService] Device time is ahead of Supabase (JWT issued at future). '
      'Signed out. Enable automatic date & time in system settings, then sign in again.',
    );
    await clearAuthSession();
  }

  static void patchLikedPostIds(List<String> ids) {
    final profile = _cachedProfile;
    if (profile == null) return;
    _cachedProfile = profile.copyWith(likedPostIds: ids);
  }

  static void patchCoins(int coins) {
    final profile = _cachedProfile;
    if (profile == null) return;
    _cachedProfile = profile.copyWith(coins: coins);
    _publishCoins(coins);
  }

  static void _publishCoins(int? coins) {
    if (coinsNotifier.value == coins) return;
    coinsNotifier.value = coins;
  }

  static Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured. Sign in is unavailable.');
    }

    final normalizedEmail = email.trim().toLowerCase();

    await client.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );

    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in failed. Please try again.');
    }

    await _ensureProfileForAuthUser(
      client: client,
      user: user,
      email: normalizedEmail,
    );

    await _syncPendingAvatarIfNeeded(
      client: client,
      userId: user.id,
      email: normalizedEmail,
    );

    await loadCurrentProfile(forceRefresh: true);
  }

  /// Sign in with Apple（仅 iOS / macOS），并与 Supabase Auth 关联。
  static Future<void> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw StateError('Sign in with Apple is only available on Apple devices.');
    }

    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured. Sign in is unavailable.');
    }

    final rawNonce = generateAppleAuthNonce();
    final hashedNonce = sha256Nonce(rawNonce);

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthException('Apple sign in was canceled.');
      }
      throw AuthException(error.message);
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Apple sign in failed. Please try again.');
    }

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Apple sign in failed. Please try again.');
    }

    final appleUserId = credential.userIdentifier?.trim() ?? '';
    if (appleUserId.isEmpty) {
      throw const AuthException('Apple sign in failed. Missing user identifier.');
    }

    final displayName = _appleDisplayName(
      givenName: credential.givenName,
      familyName: credential.familyName,
      metadata: user.userMetadata,
    );

    final existingName = (user.userMetadata?['display_name'] as String?)?.trim() ?? '';
    if (displayName.isNotEmpty && existingName.isEmpty) {
      try {
        await client.auth.updateUser(
          UserAttributes(data: {'display_name': displayName}),
        );
      } catch (error) {
        debugPrint('[AuthService] updateUser display_name: $error');
      }
    }

    final email = credential.email?.trim().toLowerCase() ??
        user.email?.trim().toLowerCase();

    await _ensureProfileForAppleUser(
      client: client,
      user: user,
      appleUserId: appleUserId,
      email: email,
      displayName: displayName,
    );

    await loadCurrentProfile(forceRefresh: true);
  }

  static String _appleDisplayName({
    String? givenName,
    String? familyName,
    Map<String, dynamic>? metadata,
  }) {
    final parts = <String>[
      if (givenName != null && givenName.trim().isNotEmpty) givenName.trim(),
      if (familyName != null && familyName.trim().isNotEmpty) familyName.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(' ');

    final metaName = (metadata?['display_name'] as String?)?.trim() ?? '';
    if (metaName.isNotEmpty) return metaName;

    final email = (metadata?['email'] as String?)?.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;

    return 'Player';
  }

  static Future<void> _ensureProfileForAppleUser({
    required SupabaseClient client,
    required User user,
    required String appleUserId,
    String? email,
    required String displayName,
  }) async {
    // 须先按 Apple ID 匹配：新 auth 会话会触发 handle_new_auth_user 再插一行，
    // 若先按 auth_user_id 写 apple_user_id 会与旧资料行冲突。
    final appleRow = await _authRepo.findByAppleUserId(client, appleUserId);
    final authRow = await _authRepo.findByAuthUserId(client, user.id);

    if (appleRow != null) {
      final profileId = appleRow['id'] as String?;
      if (profileId != null) {
        await _authRepo.linkAuthUserId(
          client: client,
          profileId: profileId,
          authUserId: user.id,
          email: (email != null && email.isNotEmpty)
              ? email
              : (appleRow['email'] as String?)?.trim() ?? '',
        );
        final authProfileId = authRow?['id'] as String?;
        if (authProfileId != null && authProfileId != profileId) {
          await _authRepo.deleteByProfileId(client, authProfileId);
        }
      }
      return;
    }

    if (authRow != null) {
      if ((authRow['apple_user_id'] as String?)?.trim().isEmpty ?? true) {
        await _authRepo.updateFields(
          client: client,
          authUserId: user.id,
          fields: {'apple_user_id': appleUserId},
        );
      }
      return;
    }

    await _authRepo.upsertProfile(
      client: client,
      authUserId: user.id,
      email: email,
      displayName: displayName,
      appleUserId: appleUserId,
    );
  }

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? bio,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Supabase is not configured. Sign up is unavailable.');
    }

    final data = <String, dynamic>{};
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      data['display_name'] = name;
    }
    final intro = bio?.trim();
    if (intro != null && intro.isNotEmpty) {
      data['bio'] = intro;
    }

    return auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: data.isEmpty ? null : data,
    );
  }

  /// 注册第二步：创建 auth 账号并写入 public."User"（含头像、简介）。
  static Future<void> completeSignUp({
    required String email,
    required String password,
    required String displayName,
    String? bio,
    String? avatarLocalPath,
    bool eulaAccepted = false,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured. Sign up is unavailable.');
    }

    final normalizedEmail = email.trim().toLowerCase();

    final existing = await _authRepo.findByEmail(client, normalizedEmail);
    if (existing != null && existing['auth_user_id'] != null) {
      throw const AuthException(
        'This email is already registered. Please sign in.',
      );
    }

    final response = await signUpWithEmail(
      email: normalizedEmail,
      password: password,
      displayName: displayName,
      bio: bio,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Registration failed. Please try again.');
    }

    final hasSession = client.auth.currentSession != null;
    String? avatarPath;

    if (hasSession &&
        avatarLocalPath != null &&
        avatarLocalPath.isNotEmpty) {
      avatarPath = await _uploadAvatar(
        client: client,
        email: normalizedEmail,
        localPath: avatarLocalPath,
      );
    } else if (avatarLocalPath != null && avatarLocalPath.isNotEmpty) {
      await PendingAvatarStorage.save(normalizedEmail, avatarLocalPath);
    }

    await _authRepo.upsertProfile(
      client: client,
      authUserId: user.id,
      email: normalizedEmail,
      displayName: displayName,
      bio: bio,
      avatarPath: avatarPath,
      eulaAccepted: eulaAccepted,
    );

    if (hasSession) {
      if (eulaAccepted) {
        await const EulaRepository().acceptEulaSignup();
      }
      // 注册成功不保留会话，须回到登录页手动登录。
      await clearAuthSession();
      return;
    }

    throw StateError(
      'Account created. Please check your email to verify, then sign in.',
    );
  }

  static Future<void> _ensureProfileForAuthUser({
    required SupabaseClient client,
    required User user,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    var row = await _authRepo.findByAuthUserId(client, user.id);
    if (row != null) return;

    row = await _authRepo.findByEmail(client, normalizedEmail);
    if (row != null) {
      final profileId = row['id'] as String?;
      if (profileId != null) {
        await _authRepo.linkAuthUserId(
          client: client,
          profileId: profileId,
          authUserId: user.id,
          email: normalizedEmail,
        );
      }
      return;
    }

    final meta = user.userMetadata ?? {};
    final name = (meta['display_name'] as String?)?.trim();
    final intro = (meta['bio'] as String?)?.trim();

    await _authRepo.upsertProfile(
      client: client,
      authUserId: user.id,
      email: normalizedEmail,
      displayName: name?.isNotEmpty == true ? name! : normalizedEmail.split('@').first,
      bio: intro,
    );
  }

  static Future<void> _syncPendingAvatarIfNeeded({
    required SupabaseClient client,
    required String userId,
    required String email,
  }) async {
    final row = await _authRepo.findByAuthUserId(client, userId);
    final existing = row?['avatar_path'] as String?;
    if (existing != null && existing.isNotEmpty) return;

    final localPath = await PendingAvatarStorage.take(email);
    if (localPath == null || localPath.isEmpty) return;

    final storagePath = await _uploadAvatar(
      client: client,
      email: email,
      localPath: localPath,
    );
    if (storagePath == null) return;

    await _authRepo.updateFields(
      client: client,
      authUserId: userId,
      fields: {'avatar_path': storagePath},
    );
  }

  /// 更新当前登录用户资料（昵称、简介、可选新头像）。
  static Future<void> updateCurrentProfile({
    required String displayName,
    required String bio,
    String? avatarLocalPath,
  }) async {
    final client = _client;
    final user = currentUser;
    if (client == null || user == null) {
      throw StateError('Not signed in. Profile update is unavailable.');
    }

    final previousPath = _cachedProfile?.avatarPath;
    final previousUrl = _cachedProfile?.avatarUrl;

    final fields = <String, dynamic>{
      'display_name':
          displayName.trim().isEmpty ? 'Player' : displayName.trim(),
      'bio': bio.trim(),
    };

    final email = _cachedProfile?.email?.trim().toLowerCase() ??
        user.email?.trim().toLowerCase() ??
        '';
    if (email.isEmpty && avatarLocalPath != null && avatarLocalPath.isNotEmpty) {
      throw StateError('Email is required to upload avatar.');
    }

    String? newStoragePath;
    if (avatarLocalPath != null && avatarLocalPath.isNotEmpty) {
      newStoragePath = await _uploadAvatar(
        client: client,
        email: email,
        localPath: avatarLocalPath,
      );
      if (newStoragePath == null || newStoragePath.isEmpty) {
        throw StateError('Avatar upload failed. Please try again.');
      }
      fields['avatar_path'] = newStoragePath;
    }

    await _authRepo.updateFields(
      client: client,
      authUserId: user.id,
      fields: fields,
    );

    if (previousPath != null && previousPath.isNotEmpty) {
      StorageMediaUrlResolver.invalidate(previousPath);
    }
    if (newStoragePath != null && newStoragePath.isNotEmpty) {
      StorageMediaUrlResolver.invalidate(newStoragePath);
    }

    await loadCurrentProfile(forceRefresh: true);

    await CachedMediaImage.evict(url: previousUrl, cacheKey: previousPath);
  }

  static Future<String?> _uploadAvatar({
    required SupabaseClient client,
    required String email,
    required String localPath,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final ext = localPath.split('.').last.toLowerCase();
      final safeExt =
          ext == 'jpg' || ext == 'jpeg' || ext == 'png' ? ext : 'jpg';
      // 每次上传使用新路径，避免 avatar_path 不变导致图片缓存仍显示旧图。
      final storagePath = StorageUserFolder.avatarObjectPath(
        email: email,
        extension: safeExt,
      );

      await client.storage.from(SupabaseConfig.mediaBucket).upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return storagePath;
    } catch (error, stack) {
      debugPrint('[AuthService] Avatar upload failed: $error');
      debugPrint('$stack');
      return null;
    }
  }

  /// 向服务端校验当前 JWT；账号已删除或 token 无效时清除本地会话。
  static Future<void> refreshSessionOrSignOut() async {
    final auth = _auth;
    if (auth == null || !isLoggedIn) return;
    try {
      final response = await auth.getUser();
      if (response.user == null) {
        await clearAuthSession();
      }
    } on AuthException catch (error) {
      debugPrint('[AuthService] getUser: $error');
      if (isJwtClockSkewError(error)) {
        await _recoverFromJwtClockSkew();
      } else {
        await clearAuthSession();
      }
    } catch (error, stack) {
      if (isJwtClockSkewError(error)) {
        await _recoverFromJwtClockSkew();
        return;
      }
      debugPrint('[AuthService] refreshSessionOrSignOut: $error');
      debugPrint('$stack');
    }
  }

  /// 清除 Supabase 登录会话（本地持久化 + 服务端注销），不清理图片/Feed 缓存。
  static Future<void> clearAuthSession({
    SignOutScope scope = SignOutScope.local,
  }) async {
    _cachedProfile = null;
    _publishCoins(null);
    FollowService.reset();
    BlockService.reset();
    LikeService.reset();
    HiddenConversationsService.reset();
    final auth = _auth;
    if (auth == null) return;
    try {
      await auth.signOut(scope: scope);
    } catch (error, stack) {
      debugPrint('[AuthService] signOut failed: $error');
      debugPrint('$stack');
      _cachedProfile = null;
      _publishCoins(null);
      rethrow;
    }
  }

  /// 退出登录（等同 [clearAuthSession]）。
  static Future<void> signOut() => clearAuthSession();

  /// 删除当前账号（先清 Storage，再删库；帖子/直播等随 FK 级联删除）。
  static Future<void> deleteAccount() async {
    final client = _client;
    final auth = _auth;
    if (client == null || auth == null || !isLoggedIn) {
      throw StateError('Not signed in. Delete account is unavailable.');
    }

    await UserStorageCleanup.purgeAllForCurrentUser(client);
    await client.rpc('delete_my_account');

    _cachedProfile = null;
    _publishCoins(null);
    FollowService.reset();
    BlockService.reset();
    LikeService.reset();
    HiddenConversationsService.reset();

    try {
      await auth.signOut(scope: SignOutScope.local);
    } catch (error, stack) {
      debugPrint('[AuthService] deleteAccount signOut: $error');
      debugPrint('$stack');
    }
  }
}
