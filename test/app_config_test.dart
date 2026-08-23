import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development uses localhost when no API base URL is supplied', () {
    final config = AppConfig.fromValues(environment: 'development');

    expect(config.baseUrl, 'http://localhost:8080');
  });

  test('normalizes an explicit HTTPS API base URL', () {
    final config = AppConfig.fromValues(
      environment: 'production',
      apiBaseUrl: ' https://api.example.com/ ',
    );

    expect(config.baseUrl, 'https://api.example.com');
  });

  test('requires an API base URL outside development', () {
    expect(
      () => AppConfig.fromValues(environment: 'staging'),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects unknown environments and non-HTTP URLs', () {
    expect(
      () => AppConfig.fromValues(
        environment: 'preview',
        apiBaseUrl: 'https://api.example.com',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: 'ftp://api.example.com',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
