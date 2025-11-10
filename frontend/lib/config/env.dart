class Env {
  static const String envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'http://106.53.190.84:8080/api/v1');
  static bool get isDev => envName.toLowerCase() == 'dev';
}
