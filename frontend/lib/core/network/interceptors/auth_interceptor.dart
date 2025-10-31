/*
 * 文件版本号: 1.0.0
 * 文件功能说明: 认证拦截器，自动处理API请求的身份验证，包括Token添加、过期检测和自动刷新机制
 * 当前已知问题:
 *   - Token刷新失败时的处理逻辑不完善
 *   - 缺少并发请求时的Token刷新锁机制
 *   - 没有处理刷新Token过期的情况
 * 修改需求说明:
 *   - 添加Token刷新锁，避免并发请求时重复刷新
 *   - 完善Token刷新失败的降级处理
 *   - 添加Token有效期检查，提前刷新即将过期的Token
 *   - 实现自动登出机制，当刷新Token也过期时
 */

import 'package:dio/dio.dart';
import '../../storage/token_storage.dart';
import '../../utils/logger.dart';

/// 认证拦截器
/// 自动添加Token到请求头，处理Token过期自动刷新
class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage = TokenStorage();
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // 获取访问令牌
    final accessToken = await _tokenStorage.getAccessToken();
    
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
      AppLogger.debug('添加Authorization头: Bearer ${accessToken.substring(0, 10)}...');
    }
    
    super.onRequest(options, handler);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 处理401未授权错误，尝试刷新Token
    if (err.response?.statusCode == 401) {
      AppLogger.warning('收到401错误，尝试刷新Token');
      
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // 刷新Token
          final success = await _refreshToken(refreshToken);
          if (success) {
            // 重新发送原始请求
            final newAccessToken = await _tokenStorage.getAccessToken();
            if (newAccessToken != null) {
              err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              
              final dio = Dio();
              final response = await dio.fetch(err.requestOptions);
              handler.resolve(response);
              return;
            }
          }
        } catch (e) {
          AppLogger.error('Token刷新失败', e);
        }
      }
      
      // Token刷新失败，清除本地Token并跳转到登录页
      await _tokenStorage.clearTokens();
      AppLogger.info('Token已清除，需要重新登录');
    }
    
    super.onError(err, handler);
  }
  
  /// 刷新访问令牌
  Future<bool> _refreshToken(String refreshToken) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        'http://localhost:8080/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        await _tokenStorage.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        
        AppLogger.info('Token刷新成功');
        return true;
      }
    } catch (e) {
      AppLogger.error('Token刷新请求失败', e);
    }
    
    return false;
  }
}