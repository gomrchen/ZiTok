# ZiTok Frontend

## 主题管理系统

本项目已采用统一的主题管理架构：

- 主题配置：`lib/shared/styles/app_colors.dart` 与 `lib/shared/styles/app_theme.dart`
- 状态管理：`lib/shared/providers/app_provider.dart`
- 设置页面集成：`lib/features/user/presentation/pages/settingsPage.dart`

### 使用方式

- 在 `MaterialApp` 中使用：
  ```dart
  MaterialApp(
    theme: context.watch<AppProvider>().currentTheme,
  )
  ```
- 切换主题：
  ```dart
  context.read<AppProvider>().setThemeMode(AppThemeMode.dark); // 或 light/system
  ```
- 主题切换按钮示例：`lib/shared/widgets/theme_toggle.dart`

### 持久化

主题与语言设置通过 `SharedPreferences` 持久化，实现于 `lib/core/storage/app_storage.dart`。

### 测试

主题切换的Widget测试位于 `test/theme_test.dart`，验证 `MaterialApp` 的 `ThemeData` 会随 `AppProvider` 的模式更新。
