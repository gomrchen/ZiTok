# 组件与页面说明（与当前代码结构同步）

本文档描述 ZiTok 前端在 Flutter + Provider + GoRouter 架构下的主要页面、组件与状态管理，路径均基于当前项目结构（`lib/` 下）。

## 项目概览
- 状态管理：`provider`
- 路由：`go_router`（路由守卫在 `lib/routes/app_router.dart`）
- 网络层：`dio` 封装于 `lib/services/api_client.dart`
- 本地存储：`shared_preferences` + `hive`
- 主题系统：`lib/theme/app_theme.dart` 与 `lib/theme/theme_tokens.dart`，通过 `ThemeProvider` 管理
- 启动注入：`lib/app.dart`（`AppBootstrap` 初始化，`MultiProvider` 注入）
- 网络检测：`connectivity_plus` 用于网络感知预加载
- 视频管理：`VideoPlaybackManager` 全局视频播放状态管理

## 路由与页面

### 认证相关
- `GET /welcome` → 欢迎页：`lib/views/welcome/welcome_page.dart`
- `GET /auth/login` → 登录页：`lib/views/auth/login_page.dart`
- `GET /auth/register` → 注册页：`lib/views/auth/register_page.dart`
- `GET /auth/forgot-password` → 忘记密码：`lib/views/auth/forgot_password_page.dart`

### 主界面
- `GET /home` → 主界面 Shell：`lib/views/home/home_shell.dart`
  - 子模块（通过 `IndexedStack` 切换）：
    - 发现：`lib/views/video/discover_page.dart`
    - 关注：`lib/views/follow/follow_page.dart`
    - 消息列表：`lib/views/messages/messages_page.dart`
    - 我：`lib/views/profile/profile_page.dart`

### 视频相关
- `GET /video/:id` → 视频详情：`lib/views/video/video_detail_page.dart`
- `GET /video/:id/notes` → 视频笔记：`lib/views/notes/video_notes_page.dart`
- `GET /video/list` → 视频列表：`lib/views/video/video_list_page.dart`

### 笔记相关
- `GET /note/:id` → 笔记详情：`lib/views/notes/note_detail_page.dart`

### 消息与社交
- `GET /messages` → 消息列表：`lib/views/messages/messages_page.dart`
- `GET /chat/:cid` → 聊天页：`lib/views/chat/chat_page.dart`

### 个人中心
- `GET /profile/edit` → 资料编辑：`lib/views/profile/edit_profile_page.dart`
- `GET /profile/video/:id/manage` → 视频管理：`lib/views/profile/video_manage_page.dart`
- `GET /profile/note/:id/manage` → 笔记管理：`lib/views/profile/note_manage_page.dart`
- `GET /user/:id` → 访客个人主页：`lib/views/profile/visitor_profile_page.dart`

### 搜索
- `GET /search` → 搜索页：`lib/views/search/search_page.dart`
- `GET /search/results` → 搜索结果：`lib/views/search/search_results_page.dart`

### 设置
- `GET /settings` → 设置页：`lib/views/settings/settings_page.dart`
- `GET /settings/change-password` → 修改密码：`lib/views/settings/change_password_page.dart`
- `GET /settings/account-switcher` → 账号切换：`lib/views/settings/account_switcher_page.dart`
- `GET /settings/account-settings` → 账号设置：`lib/views/settings/account_settings_page.dart`

说明：路由入口与守卫逻辑集中在 `lib/routes/app_router.dart`，通过 `AuthProvider` 的 `isAuthenticated` 或 `canAttemptAutoLogin` 控制受保护页面的访问。

## 通用组件

### 视频播放组件
- `AdvancedVideoPlayer`（`lib/widgets/advanced_video_player.dart`）
  - 高级视频播放器，支持全屏、进度控制、手势操作。
- `OptimizedVideoPlayer`（`lib/widgets/optimized_video_player.dart`）
  - 优化性能的视频播放器，支持预加载和缓存。
- `VideoControlsOverlay`（`lib/widgets/video_controls_overlay.dart`）
  - 视频播放控制覆盖层，包含播放/暂停、进度条、音量等控件。
- `VideoVisibilityHandler`（`lib/widgets/video_visibility_handler.dart`）
  - 视频可见性检测组件，用于自动播放/暂停。
- `VideoListWidget`（`lib/widgets/video_list_widget.dart`）
  - 视频列表滑动组件。

### 视频卡片组件
- `VideoCard`（`lib/widgets/video_card.dart`）
  - 发现页的竖向卡片，展示封面、标题、作者、时长与点赞信息。
- `VideoStats`（`lib/widgets/video_stats.dart`）
  - 视频统计信息组件，显示播放量、点赞数等。

### 交互组件
- `AnimatedLikeButton`（`lib/widgets/animated_like_button.dart`）
  - 带动画效果的点赞按钮。
- `CommentSheet`（`lib/widgets/comment_sheet.dart`）
  - 底部评论抽屉组件，支持在关注页/详情页唤起。

### 导航组件
- 底部导航组件（`lib/widgets/nav_items.dart`）
  - `NavItem`：标准底部栏条目组件
  - `PlusInlineButton`：中间"＋"创作入口（内嵌样式）
  - `MessagesItem`：带未读角标的消息入口

## Provider 与状态

- `AuthProvider`（`lib/providers/auth_provider.dart`）
  - 暴露：`isAuthenticated`、`canAttemptAutoLogin`、`loading`、`error`、`user`
  - 动作：`login(phone, password)`、`register(phone, otp, {password})`
  - 依赖：`AuthRepository`

- `VideoProvider`（`lib/providers/video_provider.dart`）
  - 列表状态：`discover`、`featured`、`follow`
  - 加载标记：`loadingDiscover`、`loadingFeatured`、`loadingFollow`
  - 分页/筛选：`refreshDiscover/Featured/Follow`、`loadMoreDiscover/Featured/Follow`，`keyword`、`filters`
  - 关注页：`followError`、`followScrollOffset`、`recommendStartIndexInFollow`
  - 点赞（本地模拟）：`toggleLike(videoId)`

- `VideoPlayerProvider`（`lib/providers/video_player_provider.dart`）
  - 视频播放状态管理，与 `VideoPlaybackManager` 配合使用
  - 支持播放/暂停控制、播放位置记录

- `MessagingProvider`（`lib/providers/messaging_provider.dart`）
  - 好友：`friends`（只读列表）、`friendById(id)`
  - 消息：`messagesFor(conversationId)`、`sendMessage(conversationId, text)`、`receiveMessage(conversationId, text, {from})`
  - 搜索：`searchFriends(query)`

- `CommentProvider`（`lib/providers/comment_provider.dart`）
  - 评论列表管理与发布

- `ProfileProvider`（`lib/providers/profile_provider.dart`）
  - 个人资料管理、作品列表、收藏管理

- `UserProvider`（`lib/providers/user_provider.dart`）
  - 用户信息管理

- `SettingsProvider`（`lib/providers/settings_provider.dart`）
  - 设置项：`pushNotifications`、`emailNotifications`、`messagePush`、`language`
  - 动作：`togglePush`、`toggleEmail`、`toggleMessagePush`、`setLanguage`

- `ThemeProvider`（`lib/providers/theme_provider.dart`）
  - 主题：`theme`、`themeName`
  - 动作：`registerTheme(name, colors, {brightness})`、`switchTheme(name)`、`toggleDark()`
  - 依赖：`AppTheme`（`lib/theme/app_theme.dart`）、`AppColors`（`lib/theme/theme_tokens.dart`）

### Provider 使用示例
```dart
// 在页面中读取并触发加载
final vp = context.watch<VideoProvider>();
final videos = vp.discover;
// 触发分页加载
context.read<VideoProvider>().loadMoreDiscover();

// 发送聊天消息
context.read<MessagingProvider>().sendMessage('u7', '你好');
```

## 服务与仓库

### 网络服务
- `ApiClient`（`lib/services/api_client.dart`）：封装 `Dio`，配置 BaseURL 与超时；开发模式可返回模拟数据。
- `AuthService`（`lib/services/auth_service.dart`）：登录/注册/资料接口；与 `ApiClient` 交互。
- `VideoService`（`lib/services/video_service.dart`）：视频列表、详情、上传等接口。
- `UserService`（`lib/services/user_service.dart`）：用户信息查询、更新接口。
- `NotesService`（`lib/services/notes_service.dart`）：笔记 CRUD 接口。
- `CommentService`（`lib/services/comment_service.dart`）：评论相关接口。
- `InteractionService`（`lib/services/interaction_service.dart`）：点赞、收藏等互动接口。
- `RelationService`（`lib/services/relation_service.dart`）：关注/粉丝关系接口。
- `SocketService`（`lib/services/socket_service.dart`）：WebSocket 实时通信服务。

### 视频播放服务
- `VideoPlaybackManager`（`lib/services/video_playback_manager.dart`）：
  - 全局视频播放状态管理器
  - 确保同一时间只有一个视频在播放
  - 跟踪当前活跃的视频页面栈
  - 路由切换时自动暂停视频
- `VideoRouteObserver`（`lib/services/video_playback_manager.dart`）：
  - 视频页面路由观察者
  - 监听路由变化，离开视频页面时自动暂停

### 数据仓库
- `AuthRepository`（`lib/repositories/auth_repository.dart`）：聚合 `AuthService` 与 `SharedPreferences`，维护 token 与用户资料。
- `VideoRepository`（`lib/repositories/video_repository.dart`）：聚合视频相关数据源。

### 缓存服务
- `CacheService`（`lib/services/cache.dart`）：本地缓存管理。
- `UserSession`（`lib/services/user_session.dart`）：用户会话状态管理。

## 数据模型
- `Video`（`lib/models/video.dart`）：视频数据结构，包含 `id`、`title`、`coverUrl`、`videoUrl`、`durationSeconds`、`author`、`likes`、`tags` 等。

## 启动与注入
- `AppBootstrap`（`lib/app.dart`）完成：
  - `Hive` 初始化与 Box 打开：`user_box`、`feed_cache_box`、`notes_box`、`messages_box`
  - 读取 `SharedPreferences`
  - 构建 `ApiClient`
- `ZitokApp`（`lib/app.dart`）通过 `MultiProvider` 注入各 Provider，并配置 `MaterialApp.router` 使用 `AppRouter`。

## 测试与运行
- 单测：
  - `test/providers/messaging_provider_test.dart`：验证消息发送与查询
  - `test/views/chat_page_test.dart`：验证聊天页发送后消息展示
- 运行测试：
  ```bash
  flutter test
  ```
- 开发模式（Windows）如需构建带插件的应用，请在系统设置中启用 Developer Mode（符号链接支持）：
  ```powershell
  start ms-settings:developers
  ```

## 注意事项

### 视频播放
- 使用 `VideoPlaybackManager` 管理全局视频播放状态，确保同一时间只有一个视频播放。
- 视频页面应在 `dispose` 时调用 `VideoPlaybackManager.instance.leaveVideoPage(controller)`。
- 可使用 `VideoPageVisibilityMixin` 混入来处理页面可见性变化。

### 主题与样式
- 主题 API 部分版本提示将 `Color.withOpacity` 替换为 `Color.withValues(alpha: ...)`；逐步迁移以避免精度损失。

### 异步与生命周期
- `async` 场景使用 `BuildContext` 时，优先在 `State` 中以 `if (!mounted) return;` 检查并避免跨异步间隙误用。

### 路由
- 路由常量建议集中管理；受保护路由已通过 `AuthProvider` 控制。
- `VideoRouteObserver` 会自动监听路由变化并暂停视频。

如需补充更详细的组件属性与交互协议，请在相应组件文件头部增加职责说明，并同步更新本文档的链接与示例代码。