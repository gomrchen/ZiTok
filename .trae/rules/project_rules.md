# ZiTok 项目开发规范文档

## 项目概述

ZiTok 是一个基于 Flutter 的短视频社交应用，采用 Clean Architecture 架构模式，支持视频播放、用户社交、笔记分享等功能。本文档定义了项目的开发规范、代码质量要求和开发流程标准。

## 1. 项目架构规范

### 1.1 目录结构规范

```
lib/
├── core/                    # 核心基础设施
│   ├── constants/          # 全局常量
│   ├── network/            # 网络层
│   │   ├── api_client.dart # API客户端
│   │   ├── exceptions/     # 网络异常
│   │   └── interceptors/   # 请求拦截器
│   ├── storage/            # 本地存储
│   └── utils/              # 工具类
├── features/               # 业务功能模块
│   ├── video/              # 视频模块
│   ├── user/               # 用户模块
│   ├── social/             # 社交模块
│   └── notes/              # 笔记模块
├── shared/                 # 共享组件
│   ├── models/             # 共享数据模型
│   ├── widgets/            # 共享UI组件
│   └── styles/             # 样式定义
└── main.dart               # 应用入口
```

### 1.2 Clean Architecture 分层规范

每个功能模块必须遵循以下三层架构：

#### Data Layer (数据层)
```
features/{module}/data/
├── datasources/            # 数据源（API、本地数据库）
├── models/                 # 数据模型（继承自实体）
└── repositories/           # 仓库实现
```

#### Domain Layer (领域层)
```
features/{module}/domain/
├── entities/               # 业务实体
├── repositories/           # 仓库接口
└── usecases/              # 用例（业务逻辑）
```

#### Presentation Layer (表现层)
```
features/{module}/presentation/
├── bloc/                   # 状态管理（BLoC）
├── pages/                  # 页面组件
└── widgets/               # 模块专用组件
```

### 1.3 前端组件组织方式

#### 1.3.1 组件分类
- **Pages**: 完整的页面组件，对应路由
- **Widgets**: 可复用的UI组件
- **Shared Widgets**: 跨模块共享的组件

#### 1.3.2 组件命名规范
- 页面组件：`{功能名}Page`（如：`VideoPlayerPage`）
- 业务组件：`{功能名}Widget`（如：`VideoCardWidget`）
- 通用组件：`{功能描述}Widget`（如：`LoadingWidget`）

#### 1.3.3 组件文件结构
```dart
// 组件文件示例
class VideoCardWidget extends StatelessWidget {
  // 1. 构造函数参数
  const VideoCardWidget({
    super.key,
    required this.video,
    this.onTap,
  });

  // 2. 属性定义
  final VideoModel video;
  final VoidCallback? onTap;

  // 3. build方法
  @override
  Widget build(BuildContext context) {
    // 实现
  }

  // 4. 私有方法
  void _handleTap() {
    // 实现
  }
}
```

### 1.4 API调用规范

#### 1.4.1 API客户端使用
```dart
// 统一使用ApiClient进行网络请求
class VideoRepository {
  final ApiClient _apiClient;
  
  VideoRepository(this._apiClient);
  
  Future<List<VideoModel>> getVideos() async {
    try {
      final response = await _apiClient.get('/videos');
      return (response.data['data'] as List)
          .map((json) => VideoModel.fromJson(json))
          .toList();
    } catch (e) {
      throw ApiException(
        code: 'GET_VIDEOS_FAILED',
        message: '获取视频列表失败',
      );
    }
  }
}
```

#### 1.4.2 API端点规范
- 基础URL：通过`AppConstants.apiBaseUrl`配置
- 版本控制：`/api/v1/`
- 资源命名：使用复数形式（如：`/videos`、`/users`）
- 查询参数：使用下划线命名（如：`page_size`、`user_id`）

#### 1.4.3 请求响应格式
```dart
// 标准API响应格式
{
  "code": 200,
  "message": "success",
  "data": {}, // 或 []
  "timestamp": "2024-01-01T00:00:00Z"
}

// 分页响应格式
{
  "code": 200,
  "message": "success",
  "data": {
    "items": [],
    "total": 100,
    "page": 1,
    "page_size": 20,
    "has_more": true
  }
}
```

### 1.5 状态管理方案

#### 1.5.1 BLoC模式规范
```dart
// 事件定义
abstract class VideoEvent {}
class LoadVideos extends VideoEvent {}
class RefreshVideos extends VideoEvent {}

// 状态定义
abstract class VideoState {}
class VideoInitial extends VideoState {}
class VideoLoading extends VideoState {}
class VideoLoaded extends VideoState {
  final List<VideoModel> videos;
  VideoLoaded(this.videos);
}
class VideoError extends VideoState {
  final String message;
  VideoError(this.message);
}

// BLoC实现
class VideoBloc extends Bloc<VideoEvent, VideoState> {
  final VideoRepository _repository;
  
  VideoBloc(this._repository) : super(VideoInitial()) {
    on<LoadVideos>(_onLoadVideos);
    on<RefreshVideos>(_onRefreshVideos);
  }
  
  Future<void> _onLoadVideos(
    LoadVideos event,
    Emitter<VideoState> emit,
  ) async {
    emit(VideoLoading());
    try {
      final videos = await _repository.getVideos();
      emit(VideoLoaded(videos));
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }
}
```

#### 1.5.2 状态管理层级
- **全局状态**: 用户认证、主题设置、网络状态
- **页面状态**: 页面级别的数据和UI状态
- **组件状态**: 组件内部的临时状态

## 2. 代码质量要求

### 2.1 代码风格指南

#### 2.1.1 Dart代码规范
遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 规范：

```dart
// 好的示例
class VideoPlayerController {
  final String videoUrl;
  bool _isPlaying = false;
  
  VideoPlayerController({required this.videoUrl});
  
  Future<void> play() async {
    if (!_isPlaying) {
      _isPlaying = true;
      await _startPlayback();
    }
  }
  
  Future<void> _startPlayback() async {
    // 实现播放逻辑
  }
}
```

#### 2.1.2 命名规范
- **类名**: PascalCase（如：`VideoPlayerWidget`）
- **方法名**: camelCase（如：`playVideo`）
- **变量名**: camelCase（如：`videoUrl`）
- **常量名**: lowerCamelCase（如：`maxVideoSize`）
- **私有成员**: 以下划线开头（如：`_isPlaying`）

#### 2.1.3 注释规范
```dart
/// 视频播放器组件
/// 
/// 支持本地和网络视频播放，提供播放控制功能
/// 
/// 示例用法：
/// ```dart
/// VideoPlayer(
///   videoUrl: 'https://example.com/video.mp4',
///   autoPlay: true,
/// )
/// ```
class VideoPlayer extends StatefulWidget {
  /// 视频URL地址
  final String videoUrl;
  
  /// 是否自动播放
  final bool autoPlay;
  
  const VideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
  });
}
```

### 2.2 性能优化标准

#### 2.2.1 Widget优化
```dart
// 使用const构造函数
const Text('Hello World');

// 使用Builder减少重建范围
Builder(
  builder: (context) => ExpensiveWidget(),
);

// 合理使用StatelessWidget和StatefulWidget
class StaticContent extends StatelessWidget {
  const StaticContent({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Text('Static content');
  }
}
```

#### 2.2.2 列表优化
```dart
// 使用ListView.builder处理大量数据
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return VideoCard(video: items[index]);
  },
);

// 使用AutomaticKeepAliveClientMixin保持状态
class VideoCard extends StatefulWidget {
  // ...
}

class _VideoCardState extends State<VideoCard> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ...
  }
}
```

#### 2.2.3 图片优化
```dart
// 使用CachedNetworkImage缓存网络图片
CachedNetworkImage(
  imageUrl: video.coverUrl,
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  fit: BoxFit.cover,
);
```

#### 2.2.4 内存管理
```dart
class VideoPlayerPage extends StatefulWidget {
  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl);
  }
  
  @override
  void dispose() {
    _controller.dispose(); // 释放资源
    super.dispose();
  }
}
```

### 2.3 错误处理机制

#### 2.3.1 异常分类
```dart
// API异常
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });
}

// 业务异常
class BusinessException implements Exception {
  final String code;
  final String message;
  
  const BusinessException({
    required this.code,
    required this.message,
  });
}
```

#### 2.3.2 错误处理策略
```dart
// Repository层错误处理
Future<List<VideoModel>> getVideos() async {
  try {
    final response = await _apiClient.get('/videos');
    return _parseVideos(response.data);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      throw const ApiException(
        code: 'TIMEOUT',
        message: '请求超时，请检查网络连接',
      );
    }
    throw ApiException(
      code: 'NETWORK_ERROR',
      message: '网络请求失败',
      statusCode: e.response?.statusCode,
    );
  } catch (e) {
    throw ApiException(
      code: 'UNKNOWN_ERROR',
      message: '未知错误',
    );
  }
}

// BLoC层错误处理
Future<void> _onLoadVideos(
  LoadVideos event,
  Emitter<VideoState> emit,
) async {
  emit(VideoLoading());
  try {
    final videos = await _repository.getVideos();
    emit(VideoLoaded(videos));
  } on ApiException catch (e) {
    emit(VideoError(e.message));
  } catch (e) {
    emit(VideoError('加载视频失败'));
  }
}
```

#### 2.3.3 用户友好的错误展示
```dart
// 错误页面组件
class ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const ErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}
```

## 3. 开发流程规范

### 3.1 分支管理策略

#### 3.1.1 分支类型
- **main**: 主分支，生产环境代码
- **develop**: 开发分支，集成最新功能
- **feature/{功能名}**: 功能分支
- **hotfix/{修复内容}**: 紧急修复分支
- **release/{版本号}**: 发布分支

#### 3.1.2 分支命名规范
```bash
# 功能分支
feature/video-player
feature/user-profile
feature/social-sharing

# 修复分支
hotfix/video-crash-fix
hotfix/login-error-fix

# 发布分支
release/v1.0.0
release/v1.1.0
```

#### 3.1.3 工作流程
1. 从`develop`分支创建`feature`分支
2. 在`feature`分支上开发功能
3. 完成后创建Pull Request到`develop`
4. 代码审查通过后合并到`develop`
5. 发布时从`develop`创建`release`分支
6. 测试通过后合并到`main`并打标签

### 3.2 代码审查标准

#### 3.2.1 审查检查项
- [ ] 代码符合项目规范
- [ ] 功能实现正确
- [ ] 错误处理完善
- [ ] 性能考虑合理
- [ ] 测试覆盖充分
- [ ] 文档更新及时

#### 3.2.2 Pull Request模板
```markdown
## 功能描述
简要描述本次提交的功能或修复

## 变更内容
- [ ] 新增功能
- [ ] Bug修复
- [ ] 性能优化
- [ ] 代码重构
- [ ] 文档更新

## 测试说明
描述如何测试本次变更

## 截图/录屏
如有UI变更，请提供截图或录屏

## 检查清单
- [ ] 代码已自测
- [ ] 单元测试已添加/更新
- [ ] 文档已更新
- [ ] 无编译警告
```

### 3.3 测试覆盖率要求

#### 3.3.1 测试分类
- **单元测试**: 测试单个函数或类
- **Widget测试**: 测试UI组件
- **集成测试**: 测试完整功能流程

#### 3.3.2 覆盖率目标
- 核心业务逻辑：≥90%
- Repository层：≥80%
- BLoC层：≥80%
- Widget层：≥70%
- 整体覆盖率：≥75%

#### 3.3.3 测试示例
```dart
// 单元测试示例
void main() {
  group('VideoRepository', () {
    late VideoRepository repository;
    late MockApiClient mockApiClient;
    
    setUp(() {
      mockApiClient = MockApiClient();
      repository = VideoRepository(mockApiClient);
    });
    
    test('should return videos when API call is successful', () async {
      // Arrange
      when(mockApiClient.get('/videos'))
          .thenAnswer((_) async => Response(
                data: {'data': [mockVideoJson]},
                statusCode: 200,
              ));
      
      // Act
      final result = await repository.getVideos();
      
      // Assert
      expect(result, isA<List<VideoModel>>());
      expect(result.length, 1);
    });
  });
}

// Widget测试示例
void main() {
  testWidgets('VideoCard should display video title', (tester) async {
    // Arrange
    const video = VideoModel(
      id: '1',
      title: 'Test Video',
      videoUrl: 'https://example.com/video.mp4',
    );
    
    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: VideoCard(video: video),
      ),
    );
    
    // Assert
    expect(find.text('Test Video'), findsOneWidget);
  });
}
```

### 3.4 持续集成/持续部署

#### 3.4.1 CI/CD流程
```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.2'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - run: flutter build apk --debug
```

#### 3.4.2 代码质量检查
- **静态分析**: `flutter analyze`
- **代码格式**: `dart format`
- **测试运行**: `flutter test`
- **覆盖率检查**: `flutter test --coverage`

## 4. 开发工具和配置

### 4.1 开发环境配置

#### 4.1.1 Flutter版本
- Flutter SDK: 3.9.2+
- Dart SDK: 3.0.0+

#### 4.1.2 IDE配置
推荐使用VS Code或Android Studio，安装以下插件：
- Flutter
- Dart
- Flutter Widget Snippets
- Bracket Pair Colorizer

#### 4.1.3 代码格式化配置
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_print: true
    prefer_single_quotes: true
```

### 4.2 依赖管理

#### 4.2.1 核心依赖
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 状态管理
  flutter_bloc: ^8.1.3
  
  # 网络请求
  dio: ^5.3.2
  
  # 本地存储
  shared_preferences: ^2.2.2
  
  # 图片缓存
  cached_network_image: ^3.3.0
  
  # 路由管理
  go_router: ^12.1.1
  
  # JSON序列化
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  
  # 代码生成
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
  
  # 测试工具
  mockito: ^5.4.2
```

## 5. 安全规范

### 5.1 数据安全
- 敏感数据加密存储
- API密钥安全管理
- 用户隐私保护

### 5.2 网络安全
- HTTPS通信
- 证书验证
- 请求签名验证

### 5.3 代码安全
- 输入验证
- SQL注入防护
- XSS攻击防护

## 6. 文档规范

### 6.1 代码文档
- 所有公共API必须有文档注释
- 复杂逻辑需要详细说明
- 示例代码要完整可运行

### 6.2 项目文档
- README.md：项目介绍和快速开始
- CHANGELOG.md：版本变更记录
- API.md：接口文档

## 7. 版本发布规范

### 7.1 版本号规范
采用语义化版本控制（Semantic Versioning）：
- 主版本号：不兼容的API修改
- 次版本号：向下兼容的功能性新增
- 修订号：向下兼容的问题修正

### 7.2 发布流程
1. 更新版本号
2. 更新CHANGELOG
3. 创建发布分支
4. 测试验证
5. 合并到主分支
6. 创建发布标签
7. 发布到应用商店

---

本文档将随着项目发展持续更新，所有团队成员都有责任遵守这些规范，确保项目的高质量和可维护性。