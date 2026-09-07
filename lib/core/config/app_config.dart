class AppConfig {
  const AppConfig._();

  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const appBuildNumber = int.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: 17,
  );

  static String get fullVersion => '$appVersion+$appBuildNumber';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://exadtracking.app/api/v1/mobile',
  );
}
