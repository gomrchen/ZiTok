/// 环境配置
/// - `ENV`：运行环境标识；
/// - `BASE_URL`：API 基础地址，默认指向生产网关；
class Env {
  /// 当前环境名称
  static const String envName = String.fromEnvironment('ENV', defaultValue: 'prod');

  /// API 基础地址（所有请求以此为前缀）
  /// 要求：统一使用 `http://106.53.190.84:8080/api/v1`
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://106.53.190.84:8080/api/v1',
  );

  /// 是否为开发环境
  static bool get isDev => envName.toLowerCase() == 'dev';
}