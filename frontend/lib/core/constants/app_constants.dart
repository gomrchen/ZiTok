/*
 * 文件版本号: 1.0.0
 * 文件功能说明: 应用全局常量定义文件，包含API配置、存储键名、分页参数、文件大小限制等系统级常量
 * 当前已知问题: 
 *   - 硬编码的API地址需要根据环境动态配置
 *   - 缺少对不同环境(开发/测试/生产)的配置支持
 * 修改需求说明:
 *   - 添加环境配置管理，支持开发、测试、生产环境的不同配置
 *   - 增加配置验证机制，确保必要参数的有效性
 *   - 添加更多业务相关的常量定义
 */

/// 应用常量
/// 定义应用中使用的全局常量
class AppConstants {
  // 应用信息
  static const String appName = 'ZiTok';
  static const String appVersion = '1.0.0';
  static const String appDescription = '知识向短视频社交平台';
  
  // API相关
  static const String baseUrl = 'http://localhost:8080/api/v1';
  static const String wsUrl = 'ws://localhost:8080/ws';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // 存储键名
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userInfoKey = 'user_info';
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  
  // 分页相关
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // 文件上传
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static const List<String> supportedVideoFormats = ['mp4', 'mov', 'avi', 'mkv'];
  
  // 缓存相关
  static const Duration cacheExpiry = Duration(hours: 24);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  
  // 动画时长
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // 防抖延迟
  static const Duration debounceDelay = Duration(milliseconds: 500);
  static const Duration searchDebounceDelay = Duration(milliseconds: 300);
  
  // 重试配置
  static const int maxRetryCount = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // 正则表达式
  static const String emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phoneRegex = r'^1[3-9]\d{9}$';
  static const String usernameRegex = r'^[a-zA-Z0-9_]{3,20}$';
  static const String passwordRegex = r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$';
  
  // 默认值
  static const String defaultAvatar = 'assets/images/default_avatar.png';
  static const String defaultCover = 'assets/images/default_cover.png';
  static const String placeholderImage = 'assets/images/placeholder.png';
  
  // 社交分享
  static const String shareUrlTemplate = 'https://zitok.app/share/{type}/{id}';
  static const String downloadUrl = 'https://zitok.app/download';
  
  // 错误消息
  static const String networkErrorMessage = '网络连接失败，请检查网络设置';
  static const String serverErrorMessage = '服务器异常，请稍后重试';
  static const String unknownErrorMessage = '未知错误，请稍后重试';
  static const String timeoutErrorMessage = '请求超时，请稍后重试';
  static const String unauthorizedErrorMessage = '未授权访问，请重新登录';
  
  // 成功消息
  static const String loginSuccessMessage = '登录成功';
  static const String registerSuccessMessage = '注册成功';
  static const String updateSuccessMessage = '更新成功';
  static const String deleteSuccessMessage = '删除成功';
  static const String uploadSuccessMessage = '上传成功';
  
  // 确认消息
  static const String deleteConfirmMessage = '确定要删除吗？';
  static const String logoutConfirmMessage = '确定要退出登录吗？';
  static const String clearCacheConfirmMessage = '确定要清除缓存吗？';
  
  // 路由名称
  static const String splashRoute = '/splash';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';
  static const String videoDetailRoute = '/video/detail';
  static const String knowledgeDetailRoute = '/knowledge/detail';
  
  // 主题相关
  static const String lightTheme = 'light';
  static const String darkTheme = 'dark';
  static const String systemTheme = 'system';
  
  // 语言相关
  static const String chineseLanguage = 'zh';
  static const String englishLanguage = 'en';
  
  // 数据使用模式
  static const String normalDataMode = 'normal';
  static const String savingDataMode = 'saving';
  static const String unlimitedDataMode = 'unlimited';
  
  // 视频质量
  static const String lowQuality = 'low';
  static const String mediumQuality = 'medium';
  static const String highQuality = 'high';
  static const String autoQuality = 'auto';
  
  // 通知类型
  static const String likeNotification = 'like';
  static const String commentNotification = 'comment';
  static const String followNotification = 'follow';
  static const String systemNotification = 'system';
  
  // 内容类型
  static const String videoContent = 'video';
  static const String knowledgeContent = 'knowledge';
  static const String articleContent = 'article';
  
  // 用户角色
  static const String normalUser = 'user';
  static const String creatorUser = 'creator';
  static const String adminUser = 'admin';
  
  // 审核状态
  static const String pendingStatus = 'pending';
  static const String approvedStatus = 'approved';
  static const String rejectedStatus = 'rejected';
  
  // 隐私设置
  static const String publicPrivacy = 'public';
  static const String friendsPrivacy = 'friends';
  static const String privatePrivacy = 'private';
}