import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_application_bookstore/features/auth/data/auth_repository.dart';
import 'package:flutter_application_bookstore/data/models/auth/captcha.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  late List<Map<String, dynamic>> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add({
        'path': request.uri.path,
        'body': body.isEmpty ? null : jsonDecode(body),
      });
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/auth/captcha') {
        request.response.write(jsonEncode({
          'code': 200,
          'message': '操作成功',
          'data': {
            'captchaId': 'captcha-1',
            'imageBase64': 'iVBORw0KGgo=',
            'expiresInSeconds': 120,
          },
        }));
      } else {
        request.response.write(jsonEncode({
          'code': 200,
          'message': '操作成功',
          'data': {
            'id': 1,
            'username': 'reader',
            'nickname': 'Reader',
            'role': 'CUSTOMER',
            'token': 'jwt-token',
          },
        }));
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  AuthRepository createRepository() {
    final client = ApiClient(
      config: AppConfig(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
      tokenStorage: TokenStorage(),
    );
    return AuthRepository(client);
  }

  test('fetchCaptcha parses the documented response fields', () async {
    final captcha = await createRepository().fetchCaptcha();

    expect(captcha, isA<Captcha>());
    expect(captcha.captchaId, 'captcha-1');
    expect(captcha.imageBase64, 'iVBORw0KGgo=');
    expect(captcha.expiresInSeconds, 120);
    expect(requests.single['path'], '/api/auth/captcha');
  });

  test('login sends captchaId and captchaCode', () async {
    await createRepository().login(
      username: 'reader',
      password: 'password',
      captchaId: 'captcha-1',
      captchaCode: 'A7K3P',
    );

    expect(requests.single['body'], {
      'username': 'reader',
      'password': 'password',
      'captchaId': 'captcha-1',
      'captchaCode': 'A7K3P',
    });
  });

  test('register sends captcha fields with optional profile fields', () async {
    await createRepository().register(
      username: 'new_reader',
      password: 'password',
      nickname: '新用户',
      email: 'reader@example.com',
      phone: '13800000000',
      captchaId: 'captcha-1',
      captchaCode: 'A7K3P',
    );

    expect(requests.single['body'], {
      'username': 'new_reader',
      'password': 'password',
      'nickname': '新用户',
      'email': 'reader@example.com',
      'phone': '13800000000',
      'captchaId': 'captcha-1',
      'captchaCode': 'A7K3P',
    });
  });
}
