# ZiTok Frontend

ZiTok 前端应用，基于 Flutter + Provider + GoRouter 架构。

## 技术栈

- **框架**: Flutter 3.x (Dart SDK ^3.9.2)
- **状态管理**: Provider 6.x
- **路由**: GoRouter 14.x
- **网络请求**: Dio 5.x
- **本地存储**: Hive + SharedPreferences
- **视频播放**: video_player + chewie
- **图片处理**: cached_network_image, image_picker, crop_your_image
- **实时通信**: web_socket_channel
- **网络检测**: connectivity_plus

## 项目结构

```
lib/
├── app.dart              # 应用入口与 Provider 注入
├── main.dart             # 主函数
├── config/               # 配置文件
├── models/               # 数据模型
├── providers/            # 状态管理
│   ├── auth_provider.dart
│   ├── video_provider.dart
│   ├── video_player_provider.dart
│   ├── messaging_provider.dart
│   ├── comment_provider.dart
│   ├── profile_provider.dart
│   ├── settings_provider.dart
│   ├── theme_provider.dart
│   └── user_provider.dart
├── repositories/         # 数据仓库层
├── routes/               # 路由配置
│   └── app_router.dart
├── services/             # API 服务层
│   ├── api_client.dart
│   ├── auth_service.dart
│   ├── video_service.dart
│   ├── video_playback_manager.dart
│   ├── notes_service.dart
│   ├── socket_service.dart
│   └── ...
├── theme/                # 主题配置
│   ├── app_theme.dart
│   └── theme_tokens.dart
├── utils/                # 工具函数
├── views/                # 页面视图
│   ├── welcome/          # 欢迎页
│   ├── auth/             # 登录/注册
│   ├── home/             # 主界面 Shell
│   ├── video/            # 视频相关页面
│   ├── notes/            # 笔记页面
│   ├── follow/           # 关注页
│   ├── messages/         # 消息列表
│   ├── chat/             # 聊天页
│   ├── profile/          # 个人中心
│   ├── settings/         # 设置
│   ├── search/           # 搜索
│   └── create/           # 创作页面
└── widgets/              # 通用组件
    ├── advanced_video_player.dart
    ├── comment_sheet.dart
    ├── video_card.dart
    ├── video_controls_overlay.dart
    └── ...
```

## 主题管理

- **主题配置**: `lib/theme/app_theme.dart` + `lib/theme/theme_tokens.dart`
- **状态管理**: `lib/providers/theme_provider.dart`

### 使用方式

```dart
// 读取当前主题
final theme = context.watch<ThemeProvider>().theme;

// 切换主题
context.read<ThemeProvider>().switchTheme('dark');
context.read<ThemeProvider>().toggleDark();
```

## 视频播放管理

项目实现了全局视频播放状态管理（`VideoPlaybackManager`）：
- 确保同一时间只有一个视频播放
- 路由切换时自动暂停视频
- 网络感知的视频预加载

## 开发指南

### 环境要求

- Flutter SDK ^3.9.2
- Dart SDK ^3.9.2

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
# 开发模式
flutter run

# 指定平台
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

### 构建发布版本

```bash
flutter build apk --release   # Android
flutter build ios --release   # iOS
flutter build windows         # Windows
flutter build web             # Web
```

### Windows 开发注意事项

如需构建带插件的应用，请在系统设置中启用 Developer Mode（符号链接支持）：

```powershell
start ms-settings:developers
```

## 测试

```bash
flutter test
```

## 文档

- [组件与页面说明](./docs/components.md)
