## 目标与范围
- 以真实 API 完成用户资料展示与编辑、头像/背景图上传、标签栏升级、管理弹窗与作品详情组件、设置页账户与安全功能。
- 移除所有模拟/本地占位数据，统一基于 `http://106.53.190.84:8080/api/v1` 的 `/user/*` 接口（参考 OpenAPI）。

## 接口与数据模型对齐
- 统一使用 `User` 模型（字段：`id/username/email/avatar_url/profile_background_image_url/name/bio/gender/birthday/created_at/updated_at/deleted_at`）。
- 服务层：`UserService` 对接 `/user/login`、`/user/register`、`/user/info`、`/user/avatar`、`/user/profile/background`、`/user/profile`、`/user/password`。
- 仓库层：`AuthRepository` 返回 `User`；`UserRepository` 提供 `getUser/updateProfile/uploadAvatar/uploadBackground` 与删除作品（调用既有 Video/Notes 仓库接口）。
- 返回码兼容：优先 `base.code=10000`，同时兼容顶层 `code=200/0` 并以 `statusCode==200` 兜底，避免出现“code=0 登录失败”。

## 状态管理设计
- 新增 `ProfileProvider`：
  - 状态：`user/loading/error`、上传进度 `avatarUploadProgress/backgroundUploadProgress`。
  - 动作：`loadUser()`、`updateProfile(name/bio/gender/birthday)`、`uploadAvatar(file)`、`uploadBackground(file)`、`refresh()`。
- 认证态依旧由 `AuthProvider` 维护；`ProfileProvider` 订阅 `AuthProvider.user` 的变化并联动刷新。

## 个人资料页改造（lib/views/profile/profile_page.dart）
- 基础信息：从 `ProfileProvider.user` 渲染昵称、简介、头像、背景图；移除 Hive 读取与所有示例/占位文案。
- 头像/背景图：调用 `ProfileProvider.uploadAvatar/uploadBackground`，通过 BottomSheet 完成选择、裁剪与上传；进度条显示 `uploadProgress`。
- 数据栏改造：
  - 将“获赞/互关/关注/粉丝”改为“视频/笔记/获赞/好友”。
  - 保留 UI 框架与占位计数，预留 `VideoRepository.countByUser`、`NotesRepository.countByUser`、`SocialRepository.likesCount/friendsCount` 的调用空位。
  - 采用布局约束与自适应文本，确保不同数量下不溢出。
- 标签栏升级：改为“我的收藏/我的笔记/我的视频”。
  - 点击“我的笔记/我的视频”弹出管理 Sheet（复用评论样式）：展示缩略图、标题、发布时间、删除按钮、详情按钮。
  - 删除：调用真实接口（`NotesService.delete(id)` 或 `VideoService.delete(id)`），成功后刷新 Provider；包含确认对话框与失败提示。
  - 详情按钮：跳转路由 `/video/:id` 或 `/note/:id`（路由常量集中管理）。

## 作品详情 Sheet 组件
- 新增 `lib/views/profile/widgets/work_detail_sheet.dart`：
  - Props：作品类型(`video|note`)、基础数据对象、回调（删除/编辑/分享）。
  - 功能：显示完整信息、顶部操作按钮（返回/编辑/分享），统一样式与动画过渡。
  - 可复用于“我的笔记/我的视频”条目的详情入口。

## 编辑资料页增强（lib/views/profile/edit_profile_page.dart）
- 表单与实时性：所有字段绑定 `ProfileProvider.user` 的副本，通过 `debounce(500ms)` 调用 `updateProfile`，并在提交按钮进行最终确认保存。
- 图片上传：沿用现有选择与裁剪流程，改为走 `ProfileProvider.upload...`，展示进度与结果反馈。
- 错误处理：所有网络操作统一 Loading 与异常提示；失败保持表单值但标记错误。

## 设置页功能（lib/views/settings/settings_page.dart）
- 账户管理二级页：
  - 展示已保存账户列表（`SharedPreferences` + 安全脱敏）。
  - 添加账户：邮箱/密码/用户名校验与持久化；成功后可“切换”。
  - 修改账户：允许更新已有条目的字段；保存后刷新列表。
  - 切换账户：更新 `AuthProvider` 与持久化，触发 `ProfileProvider.loadUser()`；提供“退出当前账户”。
- 隐私设置：搭建空壳二级页结构，后续接入。
- 安全设置：
  - 修改密码表单：旧密码/新密码；调用 `/user/password`，成功提示并可引导重新登录。

## 错误处理与加载态
- ApiClient：统一拦截器，注入 `Authorization`，将 401 转换为认证态失效并引导登录。
- 仓库：校验返回码与结构，抛出领域异常；Provider 接收并展示用户友好提示。
- 交互：所有删除与敏感操作弹确认对话框；上传显示百分比进度。

## 路由与导航
- 维护现有 `go_router`，新增底部管理 Sheet 的入口与详情导航；未登录访问受保护页面重定向到 `/auth/login`。

## 测试与验证
- 单测：
  - `ProfileProvider` 行为测试（load/update/upload 成功/失败分支）。
  - 仓库层返回码兼容测试（10000/200/0 + statusCode）。
  - 设置页账户切换与密码修改流程的仓库调用正确性。
- UI 金丝雀：资料页渲染、标签栏弹出、详情 Sheet 展示与操作按钮存在性。

## 交付与文档
- 更新接口文档片段（对齐字段与路径）。
- 变更说明：文件改动列表、接口兼容策略、状态管理新增项与使用方式。

请确认以上方案，确认后我将按此计划分阶段完成代码重构与验证。