import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_events.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../../../data/models/auth/auth_session.dart';
import '../../../data/models/auth/captcha.dart';
import '../data/auth_repository.dart';
import '../../../data/models/auth/security_question.dart';

enum AuthStatus { checking, unauthenticated, loading, authenticated }

class AuthState {
  const AuthState({required this.status, this.session, this.errorMessage});

  const AuthState.checking() : this(status: AuthStatus.checking);

  const AuthState.unauthenticated({String? errorMessage})
    : this(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  const AuthState.loading({AuthSession? session})
    : this(status: AuthStatus.loading, session: session);

  const AuthState.authenticated(AuthSession session)
    : this(status: AuthStatus.authenticated, session: session);

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && session != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository repository,
    required TokenStorage tokenStorage,
  }) : _repository = repository,
       _tokenStorage = tokenStorage,
       super(const AuthState.checking()) {
    _tokenExpiredSubscription = SessionEvents.tokenExpired.listen((_) {
      unawaited(_handleTokenExpired());
    });
  }

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;
  late final StreamSubscription<void> _tokenExpiredSubscription;

  Future<void> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }

    final savedSession =
        await _tokenStorage.readSession() ??
        AuthSession(
          id: 0,
          username: '',
          nickname: '',
          role: 'CUSTOMER',
          token: token,
        );
    try {
      await _repository.validateSession();
      state = AuthState.authenticated(savedSession);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleTokenExpired();
      } else {
        // A temporary backend outage should not discard a valid local session.
        state = AuthState.authenticated(savedSession);
      }
    } catch (_) {
      state = AuthState.authenticated(savedSession);
    }
  }

  Future<Captcha> loadCaptcha() {
    return _repository.fetchCaptcha();
  }

  Future<bool> login({
    required String username,
    required String password,
    String? captchaId,
    String? captchaCode,
  }) {
    return _runAuth(() {
      return _repository.login(
        username: username,
        password: password,
        captchaId: captchaId,
        captchaCode: captchaCode,
      );
    });
  }

  Future<bool> register({
    required String username,
    required String password,
    String? nickname,
    String? email,
    String? phone,
    required String captchaId,
    required String captchaCode,
    required List<SecurityAnswer> securityQuestions,
  }) {
    return _runAuth(() {
      return _repository.register(
        username: username,
        password: password,
        nickname: nickname,
        email: email,
        phone: phone,
        captchaId: captchaId,
        captchaCode: captchaCode,
        securityQuestions: securityQuestions,
      );
    });
  }

  Future<void> logout() async {
    await _tokenStorage.clearToken();
    state = const AuthState.unauthenticated();
  }

  Future<void> _handleTokenExpired() async {
    if (state.status == AuthStatus.unauthenticated) return;
    await _tokenStorage.clearToken();
    state = const AuthState.unauthenticated(errorMessage: '登录已过期，请重新登录');
  }

  Future<void> updateNickname(String nickname) async {
    final session = state.session;
    if (session == null) {
      return;
    }
    final updatedSession = AuthSession(
      id: session.id,
      username: session.username,
      nickname: nickname,
      role: session.role,
      token: session.token,
    );
    await _tokenStorage.saveSession(updatedSession);
    state = AuthState.authenticated(updatedSession);
  }

  Future<bool> _runAuth(Future<AuthSession> Function() action) async {
    state = AuthState.loading(session: state.session);
    try {
      final session = await action();
      await _tokenStorage.saveToken(session.token);
      await _tokenStorage.saveSession(session);
      state = AuthState.authenticated(session);
      return true;
    } on ApiException catch (error) {
      state = AuthState.unauthenticated(errorMessage: _friendlyMessage(error));
      return false;
    } catch (_) {
      state = const AuthState.unauthenticated(errorMessage: '登录服务暂时不可用，请稍后再试');
      return false;
    }
  }

  @override
  void dispose() {
    _tokenExpiredSubscription.cancel();
    super.dispose();
  }

  String _friendlyMessage(ApiException error) {
    if (error.isUnauthorized) {
      return '用户名或密码不正确';
    }
    if (error.statusCode == 409 || error.code == 409) {
      return '用户名已存在，请换一个试试';
    }
    if (error.message == 'Unable to connect to the server') {
      return '暂时无法连接服务，请确认后端已经启动';
    }
    if (error.message == 'Connection to server timed out') {
      return '连接服务超时，请稍后再试';
    }
    return appErrorMessage(error);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final controller = AuthController(
      repository: ref.watch(authRepositoryProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    );
    controller.restoreSession();
    return controller;
  },
);
