import 'dart:async';
import 'dart:io';

import 'package:flutter_application_bookstore/core/auth/session_events.dart';
import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_application_bookstore/core/network/api_client.dart';
import 'package:flutter_application_bookstore/core/network/api_exception.dart';
import 'package:flutter_application_bookstore/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  var responseStatus = HttpStatus.unauthorized;
  var responseCode = 401;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    responseStatus = HttpStatus.unauthorized;
    responseCode = 401;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response
        ..statusCode = responseStatus
        ..headers.contentType = ContentType.json
        ..write('{"code":$responseCode,"message":"用户名或密码不正确","data":null}');
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test(
    'does not expire the session when login credentials are rejected',
    () async {
      var expirationEvents = 0;
      final subscription = SessionEvents.tokenExpired.listen((_) {
        expirationEvents += 1;
      });
      addTearDown(subscription.cancel);

      final client = ApiClient(
        config: AppConfig(
          baseUrl: 'http://${server.address.address}:${server.port}',
        ),
        tokenStorage: TokenStorage(),
      );

      await expectLater(
        client.post<dynamic>(
          '/api/auth/login',
          data: {'username': 'reader', 'password': 'wrong-password'},
        ),
        throwsA(isA<ApiException>()),
      );

      expect(expirationEvents, 0);
    },
  );

  test('expires the session when a protected request is rejected', () async {
    var expirationEvents = 0;
    final subscription = SessionEvents.tokenExpired.listen((_) {
      expirationEvents += 1;
    });
    addTearDown(subscription.cancel);

    final client = ApiClient(
      config: AppConfig(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
      tokenStorage: TokenStorage(),
    );

    await expectLater(
      client.get<dynamic>('/api/user/me'),
      throwsA(isA<ApiException>()),
    );

    expect(expirationEvents, 1);
  });

  test('does not expire the session for business-code auth failures', () async {
    responseStatus = HttpStatus.ok;
    responseCode = 401;
    var expirationEvents = 0;
    final subscription = SessionEvents.tokenExpired.listen((_) {
      expirationEvents += 1;
    });
    addTearDown(subscription.cancel);

    final client = ApiClient(
      config: AppConfig(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
      tokenStorage: TokenStorage(),
    );

    for (final path in ['/api/auth/login', '/api/auth/register']) {
      await expectLater(
        client.post<dynamic>(path, data: {}),
        throwsA(isA<ApiException>()),
      );
    }

    expect(expirationEvents, 0);
  });

  test('expires the session for a protected business-code failure', () async {
    responseStatus = HttpStatus.ok;
    responseCode = 401;
    var expirationEvents = 0;
    final subscription = SessionEvents.tokenExpired.listen((_) {
      expirationEvents += 1;
    });
    addTearDown(subscription.cancel);

    final client = ApiClient(
      config: AppConfig(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
      tokenStorage: TokenStorage(),
    );

    await expectLater(
      client.get<dynamic>('/api/user/me'),
      throwsA(isA<ApiException>()),
    );

    expect(expirationEvents, 1);
  });
}
