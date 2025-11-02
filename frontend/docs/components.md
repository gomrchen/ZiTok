# 组件与页面说明（与当前代码结构同步）

本文档描述 ZiTok 前端在 Flutter + Provider + GoRouter 架构下的主要页面、组件与状态管理，路径均基于当前项目结构（`lib/` 下）。

## 项目概览
- 状态管理：`provider`
- 路由：`go_router`（路由守卫在 `lib/routes/app_router.dart`）
- 网络层：`dio` 封装于 `lib/services/api_client.dart`
- 本地存储：`shared_preferences` + `hive`
- 主题系统：`lib/theme/app_theme.dart` 与 `lib/theme/theme_tokens.dart`，通过 `ThemeProvider` 管理
- 启动注入：`lib/app.dart`（`AppBootstrap` 初始化，`MultiProvider` 注入）

## 路由与页面
- `GET /welcome` → 欢迎页：`lib/views/welcome/welcome_page.dart`
- `GET /auth/login` → 登录页：`lib/views/auth/login_page.dart`
- `GET /auth/register` → 注册页：`lib/views/auth/register_page.dart`
- `GET /home` → 主界面 Shell：`lib/views/home/home_shell.dart`
  - 子模块（通过 `IndexedStack` 切换）：
    - 发现：`lib/views/video/discover_page.dart`
    - 关注：`lib/views/follow/follow_page.dart`
    - 消息列表：`lib/views/messages/messages_page.dart`
    - 我：`lib/views/profile/profile_page.dart`
- `GET /messages` → 消息列表：`lib/views/messages/messages_page.dart`
- `GET /chat/:cid` → 聊天页：`lib/views/chat/chat_page.dart`
- `GET /friends/search` → 好友搜索：`lib/views/chat/chat_page.dart` 内 `FriendSearchPage`
- `GET /video/:id` → 视频详情：`lib/views/video/video_detail_page.dart`
- `GET /video/:id/notes` → 视频笔记：`lib/views/notes/video_notes_page.dart`
- `GET /profile/edit` → 资料编辑：`lib/views/profile/edit_profile_page.dart`
- `GET /settings` → 设置页：`lib/views/settings/settings_page.dart`

说明：路由入口与守卫逻辑集中在 `lib/routes/app_router.dart`，通过 `AuthProvider` 的 `isAuthenticated` 控制受保护页面的访问。

## 通用组件
- `VideoCard`（`lib/widgets/video_card.dart`）
  - 发现页的竖向卡片，展示封面、标题、作者、时长与点赞信息。
- `VideoGridCard`（`lib/widgets/video_grid_card.dart`）
  - 精选/双列场景使用的网格卡片，适配不同屏幕尺寸。
- `CommentSheet`（`lib/widgets/comment_sheet.dart`）
  - 底部评论抽屉组件，支持在关注页/详情页唤起。
- 底部导航组件（`lib/widgets/nav_items.dart`）
  - `NavItem`：标准底部栏条目组件
  - `PlusInlineButton`：中间“＋”创作入口（内嵌样式）
  - `MessagesItem`：带未读角标的消息入口

## Provider 与状态
- `AuthProvider`（`lib/providers/auth_provider.dart`）
  - 暴露：`isAuthenticated`、`loading`、`error`、`user`
  - 动作：`login(phone, password)`、`register(phone, otp, {password})`
  - 依赖：`AuthRepository`
- `VideoProvider`（`lib/providers/video_provider.dart`）
  - 列表状态：`discover`、`featured`、`follow`
  - 加载标记：`loadingDiscover`、`loadingFeatured`、`loadingFollow`
  - 分页/筛选：`refreshDiscover/Featured/Follow`、`loadMoreDiscover/Featured/Follow`，`keyword`、`filters`
  - 关注页：`followError`、`followScrollOffset`、`recommendStartIndexInFollow`
  - 点赞（本地模拟）：`toggleLike(videoId)`
- `MessagingProvider`（`lib/providers/messaging_provider.dart`）
  - 好友：`
    friends`（只读列表）、`friendById(id)`
  - 消息：`messagesFor(conversationId)`、`sendMessage(conversationId, text)`、`receiveMessage(conversationId, text, {from})`
  - 搜索：`searchFriends(query)`
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
- `ApiClient`（`lib/services/api_client.dart`）：封装 `Dio`，配置 BaseURL 与超时；开发模式可返回模拟数据。
- `AuthService`（`lib/services/auth_service.dart`）：登录/注册/资料接口；与 `ApiClient` 交互。
- `AuthRepository`（`lib/repositories/auth_repository.dart`）：聚合 `AuthService` 与 `SharedPreferences`，维护 token 与用户资料。
- `VideoRepository`（`lib/repositories/video_repository.dart`）：聚合视频相关数据源；当前依赖 `MockVideoService`（`lib/services/mock/mock_video_service.dart`）。

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
- 主题 API 部分版本提示将 `Color.withOpacity` 替换为 `Color.withValues(alpha: ...)`；逐步迁移以避免精度损失。
- `async` 场景使用 `BuildContext` 时，优先在 `State` 中以 `if (!mounted) return;` 检查并避免跨异步间隙误用。
- 路由常量建议集中管理；受保护路由已通过 `AuthProvider` 控制。

如需补充更详细的组件属性与交互协议，请在相应组件文件头部增加职责说明，并同步更新本文档的链接与示例代码。