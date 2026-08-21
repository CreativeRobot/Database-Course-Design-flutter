import 'package:flutter/material.dart';
import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/network/api_exception.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_application_bookstore/data/models/auth/auth_session.dart';
import 'package:flutter_application_bookstore/data/models/auth/captcha.dart';
import 'package:flutter_application_bookstore/features/auth/data/auth_repository.dart';
import 'package:flutter_application_bookstore/features/auth/presentation/auth_controller.dart';
import 'package:flutter_application_bookstore/features/auth/presentation/auth_pages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL3DQAAAABJRU5ErkJggg==';

class _CaptchaAuthRepository extends AuthRepository {
  _CaptchaAuthRepository()
    : super(
        ApiClient(
          config: const AppConfig(baseUrl: 'http://127.0.0.1:1'),
          tokenStorage: TokenStorage(),
        ),
      );

  int captchaRequests = 0;
  int loginRequests = 0;
  int registerRequests = 0;
  bool rejectLogin = false;
  bool rejectRegistration = false;

  @override
  Future<Captcha> fetchCaptcha() async {
    captchaRequests += 1;
    return Captcha(
      captchaId: 'captcha-$captchaRequests',
      imageBase64: _pngBase64,
      expiresInSeconds: 120,
    );
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    loginRequests += 1;
    if (rejectLogin) {
      throw const ApiException(
        statusCode: 400,
        code: 400,
        message: '验证码错误或已过期',
      );
    }
    return const AuthSession(
      id: 1,
      username: 'reader',
      nickname: 'Reader',
      role: 'CUSTOMER',
      token: 'token',
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
    registerRequests += 1;
    if (rejectRegistration) {
      throw const ApiException(
        statusCode: 400,
        code: 400,
        message: '验证码错误或已过期',
      );
    }
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
  Future<void> pumpAuthPage(
    WidgetTester tester,
    Widget page,
    _CaptchaAuthRepository repository,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              repository: repository,
              tokenStorage: TokenStorage(),
            ),
          ),
        ],
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> agreeToTerms(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  testWidgets('login loads a captcha and refreshes it manually', (tester) async {
    final repository = _CaptchaAuthRepository();

    await pumpAuthPage(tester, const LoginPage(), repository);

    expect(repository.captchaRequests, 1);
    expect(find.text('验证码'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byTooltip('刷新验证码'));
    await tester.pumpAndSettle();

    expect(repository.captchaRequests, 2);
  });

  testWidgets('login rejects an empty captcha code before making a request', (
    tester,
  ) async {
    final repository = _CaptchaAuthRepository();

    await pumpAuthPage(tester, const LoginPage(), repository);
    await tester.enterText(find.byType(TextFormField).at(0), 'reader');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await agreeToTerms(tester);

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(find.text('请输入验证码'), findsOneWidget);
    expect(repository.loginRequests, 0);
  });

  testWidgets('login refreshes captcha after a rejected authentication request', (
    tester,
  ) async {
    final repository = _CaptchaAuthRepository()..rejectLogin = true;

    await pumpAuthPage(tester, const LoginPage(), repository);
    await tester.enterText(find.byType(TextFormField).at(0), 'reader');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.enterText(find.byType(TextFormField).at(2), 'A7K3P');
    await agreeToTerms(tester);

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(repository.loginRequests, 1);
    expect(repository.captchaRequests, 2);
    expect(find.text('验证码错误或已过期'), findsOneWidget);
  });

  testWidgets('register loads captcha and refreshes it after a rejected request', (
    tester,
  ) async {
    final repository = _CaptchaAuthRepository()..rejectRegistration = true;

    await pumpAuthPage(tester, const RegisterPage(), repository);
    expect(repository.captchaRequests, 1);
    await tester.enterText(find.byType(TextFormField).at(0), 'new_reader');
    await tester.enterText(find.byType(TextFormField).at(4), 'password');
    await tester.enterText(find.byType(TextFormField).at(5), 'password');
    await tester.enterText(find.byType(TextFormField).at(6), 'A7K3P');
    await agreeToTerms(tester);

    await tester.tap(find.widgetWithText(FilledButton, '注册并进入书店'));
    await tester.pumpAndSettle();

    expect(repository.registerRequests, 1);
    expect(repository.captchaRequests, 2);
    expect(find.text('验证码错误或已过期'), findsOneWidget);
  });
}
