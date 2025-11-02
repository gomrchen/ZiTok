# 知音App 前端开发提示词与项目开发规则（统一版）

> 本文件统一包含两部分内容：
> 1) 优化后的提示词（用于驱动 trae 以 Flutter+Provider+GoRouter+Dio 实现前端）；
> 2) 项目开发规则（projects_rules.md）。
>
> 关联文档与资源：
> - 系统设计说明书：`f:\CodeStore\Projects\zitok_frontend\zitok\系统设计说明书.md`
> - 产品需求文档（PRD）：`f:\CodeStore\Projects\zitok_frontend\zitok\知音App-产品需求文档(PRD).md`
> - UI 参考图：`f:\CodeStore\Projects\zitok_frontend\zitok\img\*.png`
>
> 目标平台：Flutter 移动端（Android/iOS），可后续扩展到 Web。
>
>
---

## 一、优化后的提示词（供 trae 执行）

你将以 Flutter + Provider 实现“知音App”（视频与笔记结合的知识向社交短视频平台）的移动端前端。请严格依据 PRD 与系统设计说明书，并参照项目 `img` 目录中的界面图完成页面与交互，实现 P0 必须功能优先：用户系统、视频管理、推荐基础、笔记功能。同时搭建稳定的网络层与本地存储核心件，便于与后端（Golang）对接和联调。

- 技术栈与依赖（建议）：
  - 状态管理：`provider`
  - 网络：`dio`（拦截器、重试、超时、BaseOptions）
  - 序列化：`json_serializable` + `build_runner` + `json_annotation`
  - 本地存储：`shared_preferences`（轻量配置）、`hive`+`hive_flutter`（离线数据与列表缓存）
  - 视频播放：`video_player` + `chewie`
  - 图片与资源：`cached_network_image`、`flutter_svg`
  - 日志与工具：`logger`、`intl`
  - 路由：`go_router`（或保持 Navigator 2.0 方案，优先 go_router）

- 项目目录结构（请创建并按此落地）：
  - `lib/`
    - `main.dart`
    - `src/app.dart`（根部件与 MultiProvider 注入）
    - `src/config/`（环境与常量，如 `app_config.dart`、`env.dart`）
    - `src/routes/`（`app_router.dart` 路由定义与守卫）
    - `src/theme/`（主题与样式）
    - `src/utils/`（工具与扩展，如 `validators.dart`、`date_time.dart`）
    - `src/models/`（数据模型，含 `*.g.dart`）
    - `src/services/`（纯网络服务层：`auth_service.dart`、`video_service.dart`、`note_service.dart` 等）
    - `src/repositories/`（仓库层，聚合服务与本地存储：`auth_repository.dart` 等）
    - `src/providers/`（`ChangeNotifier`：`auth_provider.dart`、`feed_provider.dart`、`video_provider.dart`、`notes_provider.dart`、`profile_provider.dart`、`messaging_provider.dart`）
    - `src/widgets/`（通用组件）
    - `src/views/`（按功能分包：`auth/`、`home/`、`video/`、`notes/`、`profile/`、`messages/`、`create/`）
  - `test/`（模块化单测）

- 路由与页面清单（对应 `img` 目录）：
  - `/welcome` → 欢迎页（`欢迎界面.png`）
  - `/auth/login` → 登录（`登录界面.png`）
  - `/auth/register` → 注册（`注册界面.png`）
  - `/home/discover` → 发现 Feed（`主界面发现.png`）
  - `/home/featured` → 精选双列 Feed（`主界面精选.png`）
  - `/video/:id` → 视频详情（含“详情/评论”Tab，`视频详情界面-详情-评论区.png`）
  - `/video/:id/notes` → 视频关联笔记 Tab（`视频详情界面-笔记.png`）
  - `/create` → 创作页（视频+文档，`创作界面.png`、`创作界面-上传笔记状态.png`）
  - `/messages` → 私信列表（`私信界面.png`）
  - `/chat/:conversationId` → 聊天（`聊天界面.png`）
  - `/profile/edit` → 资料编辑（`个人资料编辑界面.png`）
  - `/profile/:id/notes` → 个人笔记（`个人界面-笔记.png`）
  - `/profile/:id/favorites` → 个人收藏（`个人界面-收藏.png`）

- 状态管理要求：
  - 在 `src/app.dart` 顶层以 `MultiProvider` 注入各 Provider。
  - Provider 职责单一：页面状态与轻业务，重业务走 `repositories/`。
  - 统一使用不可变 Model（`copyWith`），Provider 内部维护 UI 状态（loading/error/empty/data）。

- 网络层要求：
  - 以 `Dio` 封装 `ApiClient`，配置拦截器：日志、鉴权（JWT）、错误码转换、网络重试（指数退避）。
  - 统一响应格式（按后端约定）：
    ```json
    { "code": 200, "message": "success", "data": {}, "timestamp": 1640995200 }
    ```
  - 将后端错误码映射到前端异常类型：
    - 40001: 手机号已注册 → `AuthError.phoneExists`
    - 40002: 验证码无效 → `AuthError.invalidOtp`
    - 40003: 账户封禁 → `AuthError.banned`
    - 40101: 令牌过期 → 触发刷新或强制重新登录
    - 50001~50005: 视频相关错误 → `VideoError.*`
    - 60001~60004: 社交相关错误 → `SocialError.*`
    - 70001~70005: 笔记相关错误 → `NoteError.*`
    - 80001~80004: 推荐/搜索相关错误 → `RecommendError.*`

- 本地存储要求：
  - `SharedPreferences`：存 JWT、用户基础配置、首启标记。
  - `Hive`：模块化 Box，例如：`user_box`、`notes_box`、`feed_cache_box`、`messages_box`。
  - 离线策略：Feed 与笔记支持离线查看；网络恢复后增量同步（按系统设计说明书的同步策略）。

- 后端对接（Golang）接口约定（示例，按系统设计说明书）：
  - Auth：`POST /api/v1/auth/register`、`POST /api/v1/auth/verify`、`POST /api/v1/auth/login`、`POST /api/v1/auth/refresh`、`POST /api/v1/auth/logout`
  - User：`GET /api/v1/user/profile`、`PUT /api/v1/user/profile`、`GET /api/v1/user/notifications`
  - Video：`POST /api/v1/video/upload/init`、`POST /api/v1/video/upload/complete`、`GET /api/v1/video/{id}`、`GET /api/v1/video/{id}/stats`
  - Feed：`GET /api/v1/recommend/feed`、`GET /api/v1/feed/featured`、`GET /api/v1/search?q=...`
  - Notes：`POST /api/v1/note/create`、`PUT /api/v1/note/{id}`、`GET /api/v1/note/video/{videoId}`、`GET /api/v1/note/user/{userId}`
  - Social：`POST /api/v1/social/like`、`POST /api/v1/social/comment`、`POST /api/v1/social/follow`、`DELETE /api/v1/social/follow/{id}`
  - Messaging：`GET /api/v1/messages`、`POST /api/v1/messages`、`GET /api/v1/messages/{conversationId}`

- 开发里程碑（先做 P0）：
  1) 用户系统：注册/登录/资料编辑/权限控制（P0）
  2) 视频管理：上传流程 UI、播放、基础信息展示（P0）
  3) 推荐基础：发现与精选 Feed、行为上报（埋点）（P0）
  4) 社交功能：点赞、评论、关注、取消关注、私信列表、聊天（P0）
  5) 笔记功能：笔记上传、编辑、删除、列表展示，笔记作为视频的附件上传，笔记与视频的关联通过视频 ID 实现。（P0）

- 任务执行顺序（Cursor 落地步骤）：
  1) 初始化依赖与目录结构；配置 `analysis_options.yaml`
  2) 建立 `ApiClient`、拦截器、统一响应与错误映射
  3) 完成 `repositories/` 与核心 `providers/`（Auth/Feed/Video/Notes）
  4) 按路由清单逐页实现 UI 与交互，贴合 `img` 参考图
  5) 打通认证与基本数据流（登录后加载个性化 Feed）
  6) 视频详情与笔记联动；时间戳标记与截图占位
  7) 提交基础单测；联调后端并完成错误处理与重试

- 验收标准（节选）：
  - 登录/注册 < 500ms 响应，失败给出明确提示
  - 视频首帧 < 1s、切换 < 200ms、缓冲 < 0.5s（良好网络）
  - Feed 上下滑动流畅（>60fps）、精选双列加载稳定
  - 笔记创建 < 200ms、本地→云端增量同步可验证
  - 错误码转义清晰、令牌过期自动刷新或退出

---

## 二、项目开发规则（projects_rules.md）

- 目录结构与命名
  - 遵循上文目录；文件名 `snake_case`，类名 `PascalCase`，Provider 以 `*Provider` 结尾，Service 以 `*Service` 结尾，Repository 以 `*Repository` 结尾。
  - Model 不含业务逻辑，仅数据与 `fromJson/toJson`、`copyWith`。

- Provider 使用规范
  - 仅维护 UI 态与轻业务；重业务（网络/存储聚合）下沉至 Repository。
  - 暴露只读状态（data/error/loading）；提供明确的动作方法（如 `login`、`loadFeed`）。
  - 禁止在 Provider 中直接操作 `Dio`；通过 Service/Repository 访问。

- 网络层规范
  - `ApiClient` 统一配置：BaseURL（多环境）、超时（连接 10s/读写 20s）、`User-Agent`、`Accept-Language`。
  - 拦截器：
    - Auth：JWT 注入与刷新（401 → 刷新令牌；失败则登出）。
    - Logger：开发环境详细日志，生产环境精简。
    - Retry：网络错误指数退避，最多 3 次。
  - 统一响应解包：检测 `code` 字段，成功返回 `data`，失败抛业务异常。

- 本地存储规范
  - `SharedPreferences`：`access_token`、`refresh_token`、`user_id`、`onboarding_done`。
  - `Hive`：
    - `user_box` 保存用户画像与偏好；
    - `feed_cache_box` 保存最近 Feed；
    - `notes_box` 保存用户笔记（含版本与同步状态）；
    - `messages_box` 保存最近会话与消息快照。
  - 离线优先：列表页先读本地缓存，再并发拉取更新，合并去重。

- 模型与序列化
  - 使用 `json_serializable`；`DateTime` 统一 ISO 8601；数字类型与枚举严格匹配后端协议。
  - 大对象分页加载；避免一次性全量取回。

- 错误处理与重试
  - 将错误码映射到可读提示；避免“失败请重试”的笼统文案。
  - 网络断开：进入离线模式（Feed/笔记可浏览），恢复后提示增量同步。

- 日志与监控
  - `logger` 记录关键操作与异常；屏蔽敏感数据（手机号中间 4 位脱敏）。
  - 后续可接入埋点 SDK（点击、播放、完播、笔记创建等）。

- 主题与设计系统
  - 统一颜色与字号，抽象 `AppTheme`；支持明暗主题切换。
  - 组件库自建于 `src/widgets/`，避免页面内重复样式。

- 资源管理
  - 图片与 SVG 统一走 `assets/`，在 `pubspec.yaml` 显式声明。
  - 网络图片使用 `cached_network_image`，配置占位与失败重试。

- 路由与导航
  - 使用 `go_router`；路由常量集中管理；认证路由守卫（未登录跳转 `/auth/login`）。
  - 详情页参数采用路径参数（如 `/video/:id`）。

- 性能与可访问性
  - 列表虚拟化与懒加载；避免重绘与重复请求。
  - 文本对比度达标；元素触控区域最小 44dp。

- 国际化与时区
  - 使用 `intl`；所有时间统一为服务器 UTC，前端按本地化显示。

- 测试策略
  - 单测优先：Provider、Repository、ApiClient 解包与错误映射。
  - UI 可作金丝雀测试（Smoke Tests），确保关键路径可用。

- 构建与多环境
  - `--dart-define=BASE_URL`、`--dart-define=ENV=dev|staging|prod`；
  - 在 `src/config/env.dart` 读取并暴露。

- 安全与权限
  - 避免在日志/崩溃中输出敏感信息；
  - Token 过期自动刷新；刷新失败清理状态并退出登录。

- Git 提交与分支
  - 分支：`feature/*`、`fix/*`、`release/*`。
  - 提交信息：`feat: `、`fix: `、`refactor: `、`docs: `、`test: ` 等规范前缀。

- 文档与注释
  - 关键模块（Provider/Repository/Service/Model/Widget/View/Page）需文件头简述职责；
  - README 更新主要页面与依赖说明，联调注意事项。

- 与后端联调流程
  1) 对齐接口定义与错误码；
  2) 本地模拟数据与环境切换；
  3) 打通鉴权与推荐 Feed；
  4) 视频详情与笔记联动；
  5) 问题复盘与接口微调。

- 代码评审与质量门槛
  - `flutter analyze` 无警告；关键模块需单测通过；
  - PR 需包含截图或说明（页面变更/接口改动）。

---

### 依赖建议（pubspec.yaml 片段参考）

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  dio: ^5.5.0
  json_annotation: ^4.9.0
  shared_preferences: ^2.3.3
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  video_player: ^2.9.1
  chewie: ^1.7.5
  cached_network_image: ^3.3.1
  flutter_svg: ^2.0.9
  go_router: ^14.2.0
  intl: ^0.19.0
  logger: ^2.2.0

dev_dependencies:
  build_runner: ^2.4.9
  json_serializable: ^6.8.0
  flutter_test:
    sdk: flutter
```

---

### 开发小贴士
- 使用env文件切换开发与生产环境从而实现mock数据与真实数据的切换。
- 优先完成 P0 路由与 Provider 骨架，随后逐页贴合 `img` 参考图。
- 统一按钮/卡片/标签等通用组件，减少页面内重复样式代码。
- 遵循“视图（UI）→Provider（状态）→Repository（业务）→Service（网络）→后端”的自上而下调用链。
- 当后端接口未就绪时，用本地 `mock/*.json` 与 `Hive` 提供假数据，保持页面联通性。