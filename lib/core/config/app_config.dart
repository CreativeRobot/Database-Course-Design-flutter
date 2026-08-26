import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.environment = AppEnvironment.development,
  });

  factory AppConfig.fromDartDefines() => AppConfig.fromValues(
    environment: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
  );

  factory AppConfig.fromValues({
    required String environment,
    String? apiBaseUrl,
  }) {
    final parsedEnvironment = AppEnvironment.parse(environment);
    final candidate = apiBaseUrl?.trim() ?? '';
    if (candidate.isEmpty) {
      throw StateError(
        'API_BASE_URL is required when APP_ENV is ${parsedEnvironment.name}',
      );
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('API_BASE_URL must be an absolute HTTP(S) URL');
    }

    if (parsedEnvironment == AppEnvironment.production &&
        uri.scheme != 'https') {
      throw StateError('Production API_BASE_URL must use HTTPS');
    }
    return AppConfig(
      baseUrl: candidate.replaceFirst(RegExp(r'/+$'), ''),
      environment: parsedEnvironment,
    );
  }

  final String baseUrl;
  final AppEnvironment environment;
}
