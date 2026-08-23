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
      if (parsedEnvironment == AppEnvironment.development) {
        return AppConfig(
          baseUrl: 'http://localhost:8080',
          environment: parsedEnvironment,
        );
      }
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

    return AppConfig(
      baseUrl: candidate.replaceFirst(RegExp(r'/+$'), ''),
      environment: parsedEnvironment,
    );
  }

  final String baseUrl;
  final AppEnvironment environment;
}
