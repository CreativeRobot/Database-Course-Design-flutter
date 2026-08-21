import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_application_bookstore/data/models/auth/auth_session.dart';
import 'package:flutter_application_bookstore/data/models/auth/captcha.dart';
import 'package:flutter_application_bookstore/features/auth/data/auth_repository.dart';
import 'package:flutter_application_bookstore/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
      : super(
          ApiClient(
            config: const AppConfig(baseUrl: 'http://127.0.0.1:1'),
            tokenStorage: TokenStorage(),
          ),
        );

  String? loginCaptchaId;
  String? loginCaptchaCode;
  String? registerCaptchaId;
  String? registerCaptchaCode;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    loginCaptchaId = captchaId;
    loginCaptchaCode = captchaCode;
    return const AuthSession(
      id: 1,
      username: 'reader',
      nickname: 'Reader',
      role: 'CUSTOMER',
      token: 'token',
    );
  }

  @override
  Future<Captcha> fetchCaptcha() async {
    return const Captcha(
      captchaId: 'id',
      imageBase64: 'image',
      expiresInSeconds: 120,
    );
  }

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
    String? nickname,
    String? email,
    String? phone,
    required String captchaId,
    required String captchaCode,
  }) async {
    registerCaptchaId = captchaId;
    registerCaptchaCode = captchaCode;
    return const AuthSession(
      id: 2,
      username: 'new_reader',
      nickname: '',
      role: 'CUSTOMER',
      token: 'token',
    );
  }
}

void main() {
  test('login forwards captcha values to the repository', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeAuthRepository();
    final controller = AuthController(
      repository: repository,
      tokenStorage: TokenStorage(),
    );
    addTearDown(controller.dispose);

    final result = await controller.login(
      username: 'reader',
      password: 'password',
      captchaId: 'captcha-1',
      captchaCode: 'A7K3P',
    );

    expect(result, isTrue);
    expect(repository.loginCaptchaId, 'captcha-1');
    expect(repository.loginCaptchaCode, 'A7K3P');
  });

  test('register forwards captcha values to the repository', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeAuthRepository();
    final controller = AuthController(
      repository: repository,
      tokenStorage: TokenStorage(),
    );
    addTearDown(controller.dispose);

    final result = await controller.register(
      username: 'new_reader',
      password: 'password',
      captchaId: 'captcha-2',
      captchaCode: 'X9M2Q',
    );

    expect(result, isTrue);
    expect(repository.registerCaptchaId, 'captcha-2');
    expect(repository.registerCaptchaCode, 'X9M2Q');
  });
}
