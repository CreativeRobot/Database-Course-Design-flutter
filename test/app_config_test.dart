import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires an API base URL for development', () {
    expect(
      () => AppConfig.fromValues(environment: 'development'),
      throwsA(isA<StateError>()),
    );
  });

  test('accepts an explicit development API base URL', () {
    final config = AppConfig.fromValues(
      environment: 'development',
      apiBaseUrl: 'http://10.0.2.2:8080',
    );

    expect(config.baseUrl, 'http://10.0.2.2:8080');
  });

  test('normalizes an explicit HTTPS API base URL', () {
    final config = AppConfig.fromValues(
      environment: 'production',
      apiBaseUrl: ' https://api.example.com/ ',
    );

    expect(config.baseUrl, 'https://api.example.com');
  });

  test('requires HTTPS for production API base URLs', () {
    expect(
      () => AppConfig.fromValues(
        environment: 'production',
        apiBaseUrl: 'http://api.example.com',
      ),
      throwsA(isA<StateError>()),
    );
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
