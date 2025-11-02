class Env {
  static const String envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'http://localhost:8080');
  static bool get isDev => envName.toLowerCase() == 'dev';
}