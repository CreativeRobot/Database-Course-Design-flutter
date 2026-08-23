enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String rawValue) {
    return switch (rawValue.trim().toLowerCase()) {
      'development' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw StateError('Unsupported APP_ENV: $rawValue'),
    };
  }
}
