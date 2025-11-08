# ZiTok API 文档

本项目使用 CloudWeGo Hertz 作为 HTTP 网关，Kitex 作为 RPC 框架。接口统一以 `/douyin` 为路径前缀，部分路由末尾带有 `/`（务必注意）。

## 概览

- 基础地址：`http://127.0.0.1:10001`（可在 `deploy/config/config.yaml` 的 `services.api.addr` 中配置）
- 路由前缀：`/douyin`
- 返回格式：所有接口返回 JSON，包含 `status_code` 和可选 `status_msg`
- 认证方式：多数接口需要 `token`，通过登录/注册获取；`token` 可在查询参数或表单字段中传入
- 速率限制：网关开启 Sentinel 流控，被限流时返回 HTTP 400，`{"status_code": -1, "status_msg": "too many request; the quota used up"}`

## 认证

- 获取方式：
  - `POST /douyin/user/register/` 使用 `username`、`password` 注册，返回 `token`
  - `POST /douyin/user/login/` 使用 `username`、`password` 登录，返回 `token`
- 使用位置：
  - 查询参数：`?token=...`
  - `application/x-www-form-urlencoded` 或 `multipart/form-data` 的表单字段：`token=...`
- 校验逻辑：`cmd/api/biz/middleware/jwt.go` 中的 `AuthToken()` 会从 Query 或 Form 中读取 `token` 并校验

## 通用响应

- 成功：`status_code = 0`，`status_msg` 可选，按各接口的响应模型返回数据
- 失败：返回 `{"status_code": -1, "status_msg": "[错误码] 错误信息"}`（统一封装于 `cmd/api/biz/pack/pack.go`）
- 错误码定义见 `pkg/errno`：
  - `0` / `10000`：成功
  - `10001`：服务错误（启动/内部）
  - `10002`：参数错误
  - `10003`：鉴权失败
  - `10004`：未知类型
  - `10005`：未实现
  - `10006`：敏感词
  - `10007`：已点赞
  - `10008`：未点赞
  - `10009`：文件上传错误 / 非视频文件
  - `10010`：关注自己
  - `10011`：尚未取关
  - `10012`：已关注
  - `10013`：消息字数错误

## 模型（简要）

- `User`：`id`、`name`、`follow_count?`、`follower_count?`、`is_follow`、`avatar?`、`background_image?`、`signature?`、`total_favorited?`、`work_count?`、`favorite_count?`
- `Video`：`id`、`author(User)`、`play_url`、`cover_url`、`favorite_count`、`comment_count`、`is_favorite`、`title`
- `Comment`：`id`、`user(User)`、`content`、`create_date`
- `Message`：`id`、`to_user_id`、`from_user_id`、`content`、`create_time`
- `FriendUser`：`id`、`name`、`is_follow`、...、`message?`、`msgType`（0=接收，1=发送）

完整模型字段可参考 `idl/api.thrift`。

## 基础模块（BasicService）

- GET `/douyin/feed/`
  - 认证：可选 `token`
  - 参数：
    - `latest_time?` `i64`：时间戳（毫秒），用于分页拉流
    - `token?` `string`
  - 响应：`video_list`（`Video[]`）、`next_time?` `i64`

- POST `/douyin/user/register/`
  - 认证：不需要
  - 参数（form 或 JSON）：`username`、`password`
  - 响应：`user_id`、`token`

- POST `/douyin/user/login/`
  - 认证：不需要
  - 参数（form 或 JSON）：`username`、`password`
  - 响应：`user_id`、`token`

- GET `/douyin/user/`
  - 认证：需要 `token`
  - 参数（query）：`user_id`、`token`
  - 响应：`user`（`User`）

- POST `/douyin/publish/action/`
  - 认证：需要 `token`
  - 参数：
    - 表单类型：`multipart/form-data`
    - 文件字段：`data`（视频文件，后端会校验为视频类型）
    - 文本字段：`title` `string`、`token` `string`
  - 响应：无额外数据（`status_code`、`status_msg`）
  - 备注：
    - 最大请求体：`1<<31`（约 2GB，由 Hertz 服务器配置）
    - 文件类型校验：头部与内容双重校验 `utils.IsVideoFile` + `filetype.IsVideo`

- GET `/douyin/publish/list/`
  - 认证：需要 `token`
  - 参数（query）：`user_id`、`token`
  - 响应：`video_list`（`Video[]`）

## 互动模块（InteractionService）

- POST `/douyin/favorite/action/`
  - 认证：需要 `token`
  - 参数：`token`、`video_id`、`action_type`（1=点赞，2=取消点赞）
  - 响应：仅状态

- GET `/douyin/favorite/list/`
  - 认证：需要 `token`
  - 参数（query）：`user_id`、`token`
  - 响应：`video_list`（已点赞 `Video[]`）

- POST `/douyin/comment/action/`
  - 认证：需要 `token`
  - 参数：
    - `token`、`video_id`、`action_type`
    - 当 `action_type=1`（发表评论）：需要 `comment_text`
    - 当 `action_type=2`（删除评论）：需要 `comment_id`
  - 响应：当发表评论成功时返回 `comment`（`Comment`）

- GET `/douyin/comment/list/`
  - 认证：需要 `token`
  - 参数（query）：`video_id`、`token`
  - 响应：`comment_list`（`Comment[]`）

## 社交模块（SocialService）

- POST `/douyin/relation/action/`
  - 认证：需要 `token`
  - 参数：`token`、`to_user_id`、`action_type`（1=关注，2=取消关注）
  - 响应：仅状态

- GET `/douyin/relation/follow/list/`
  - 认证：需要 `token`
  - 参数（query）：`user_id`、`token`
  - 响应：`user_list`（`User[]`）

- GET `/douyin/relation/follower/list/`
  - 认证：需要 `token`
  - 参数（query）：`user_id`、`token`
  - 响应：`user_list`（`User[]`）

- GET `/douyin/relation/friend/list/`
  - 认证：需要 `token`
  - 参数（query）：`user_id`、`token`
  - 响应：`user_list`（`FriendUser[]`，包含最近消息及消息方向）

## 消息模块（SocialService）

- POST `/douyin/message/action/`
  - 认证：需要 `token`
  - 参数：`token`、`to_user_id`、`action_type=1`、`content`
  - 响应：仅状态

- GET `/douyin/message/chat/`
  - 认证：需要 `token`
  - 参数（query）：`to_user_id`、`token`
  - 响应：`message_list`（`Message[]`）

## 路由与鉴权说明

- 具体路由注册见：`cmd/api/biz/router/api/api.go`
- 需要鉴权的端点在 `cmd/api/biz/router/api/middleware.go` 中绑定了 `AuthToken()`
- 未绑定鉴权的端点：`/douyin/feed/`、`/douyin/user/register/`、`/douyin/user/login/`

## 示例

- 登录并获取 `token`

```bash
curl -X POST "http://127.0.0.1:10001/douyin/user/login/" \
  -d "username=alice" -d "password=secret"
```

- 获取首页流

```bash
curl "http://127.0.0.1:10001/douyin/feed/?latest_time=0&token=YOUR_TOKEN"
```

- 发布视频（multipart）

```bash
curl -X POST "http://127.0.0.1:10001/douyin/publish/action/" \
  -H "Content-Type: multipart/form-data" \
  -F "data=@/path/to/video.mp4" \
  -F "title=My first video" \
  -F "token=YOUR_TOKEN"
```

## 其它

- 已提供 OpenAPI 文档：`/.postman/tiktok.openapi.json`（可导入 Postman）
- 服务端中间件：
  - `cors`：允许所有来源与常见方法
  - `gzip`：启用压缩
  - `recovery`：统一异常恢复
  - `sentinel`：流控与降级
- 健康检查：`GET /ping` 返回 `{"message": "pong"}`

如需扩展或生成更详细的 OpenAPI 3.0 文档，我可以基于 `idl/api.thrift` 自动转换并补充示例与枚举说明。