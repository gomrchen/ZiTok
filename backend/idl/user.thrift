namespace go user

include "model.thrift"

// 注册请求
struct RegisterRequest {
    1: required string username   // 用户名
    2: required string password   // 密码
    3: optional string email      // 邮箱
    4: required string code
}

struct PasswordRequest {
    2: required string newPwd   // 密码
    3: optional string email      // 邮箱
    4: required string code
}

// 注册响应
struct PasswordResponse {
    1: required model.BaseResp Base // 基本响应信息
}

// 注册响应
struct RegisterResponse {
    1: required model.BaseResp Base // 基本响应信息
    2: required i64 user_id         // 用户ID
}

// 登录请求
struct LoginRequest {
    1: required string username   // 用户名 
    2: required string password   // 密码
}

// 登录响应
struct LoginResponse {
    1: required model.BaseResp Base // 基本响应信息
    2: required i64 user_id         // 用户ID
    3: required string token        // 访问令牌
    4: required string refresh_token // 刷新令牌
}

// 获取用户信息请求
struct UserInfoRequest {
    1: required i64 user_id             // 用户ID
}

// 获取用户信息响应
struct UserInfoResponse {
    1: required model.BaseResp Base // 基本响应信息
    2: required model.User User     // 用户信息 (包含model中新增的背景图、签名等字段)
}

// 更新用户信息请求
struct UpdateUserInfoRequest {
    1: optional i64 user_id           // 用户ID (如果不为空则使用此ID，否则从上下文获取)
    2: optional string username       // 用户名
    3: optional string password       // 密码
    4: optional string signature      // 简介/个性签名
    5: optional i64 gender            // 性别 0:未知 1:男 2:女
    6: optional string birthday       // 生日 YYYY-MM-DD
    7: optional string email          // 邮箱
    8: optional string background_url // 背景图URL (如果是直接传URL的方式)
    9: optional string avatar_url     // 头像URL (如果是直接传URL的方式)
}

// 更新用户信息响应
struct UpdateUserInfoResponse {
    1: required model.BaseResp Base // 基本响应信息
}

// 上传头像请求
struct UploadAvatarRequest {
    1: required binary avatar_data     // 头像二进制数据
    2: required string content_type    // 文件类型 (image/png, image/jpeg)
}

// 上传头像响应
struct UploadAvatarResponse {
    1: required model.BaseResp Base // 基本响应信息
    2: required model.User User     // 返回更新后的用户信息(包含新头像URL)
}

// --- 新增：背景图上传 ---

// 上传背景图请求
struct UploadBackgroundRequest {
    1: required binary background_data // 背景图二进制数据
    2: required string content_type    // 文件类型
}

// 上传背景图响应
struct UploadBackgroundResponse {
    1: required model.BaseResp Base // 基本响应信息
    2: required model.User User     // 返回更新后的用户信息(包含新背景URL)
}

// 刷新令牌请求
struct RefreshTokenRequest {
    1: required i64 user_id
    2: required string refresh_token   // 刷新令牌
}

// 刷新令牌响应
struct RefreshTokenResponse {
    1: required model.BaseResp Base // 基本响应信息
    2: required string token         // 新的访问令牌
    3: required string refresh_token // 新的刷新令牌
}


// 用户简要信息
struct UserBrief {
    1: required i64 user_id
    2: required string username
    3: required string avatar_url
}

// 根据用户名模糊匹配查找用户请求
struct FindUsersByUsernameRequest {
    1: required string username
}

// 根据用户名模糊匹配查找用户响应
struct FindUsersByUsernameResponse {
    1: required model.BaseResp Base
    2: required list<UserBrief> users
}

// 根据邮箱查找用户ID请求
struct FindUserByEmailRequest {
    1: required string email
}

// 根据邮箱查找用户ID响应
struct FindUserByEmailResponse {
    1: required model.BaseResp Base
    2: required i64 user_id
}

// --- 收藏相关 ---

// 收藏视频请求
struct FavoriteVideoRequest {
    1: required i64 video_id         // 视频ID
}

// 收藏视频响应
struct FavoriteVideoResponse {
    1: required model.BaseResp Base  // 基本响应信息
}

// 取消收藏视频请求
struct UnfavoriteVideoRequest {
    1: required i64 video_id         // 视频ID
}

// 取消收藏视频响应
struct UnfavoriteVideoResponse {
    1: required model.BaseResp Base  // 基本响应信息
}

// 获取收藏视频列表请求
struct GetFavoriteVideosRequest {
    1: required i32 page             // 页码
    2: required i32 size             // 每页大小
}

// 获取收藏视频列表响应
struct GetFavoriteVideosResponse {
    1: required model.BaseResp Base              // 基本响应信息
    2: required list<model.Video> VideoList      // 视频列表
    3: required i64 total                        // 总数
}


// 用户服务
service UserService {
    // 用户注册
    RegisterResponse Register(1: RegisterRequest req)

    // 用户登录
    LoginResponse Login(1: LoginRequest req)

    // 获取用户信息
    UserInfoResponse GetUserInfo(1: UserInfoRequest req)

    // 更新用户信息 (新增)
    UpdateUserInfoResponse UpdateUserInfo(1: UpdateUserInfoRequest req)

    // 上传头像
    UploadAvatarResponse UploadAvatar(1: UploadAvatarRequest req)

    // 上传背景图片 (新增)
    UploadBackgroundResponse UploadBackground(1: UploadBackgroundRequest req)

    // 刷新令牌
    RefreshTokenResponse RefreshToken(1: RefreshTokenRequest req)

    // 根据用户名模糊匹配查找用户
    FindUsersByUsernameResponse FindUsersByUsername(1: FindUsersByUsernameRequest req)

    // 根据邮箱查找用户ID
    FindUserByEmailResponse FindUserByEmail(1: FindUserByEmailRequest req)

    // --- 收藏相关 ---

    // 收藏视频
    FavoriteVideoResponse FavoriteVideo(1: FavoriteVideoRequest req)

    // 取消收藏视频
    UnfavoriteVideoResponse UnfavoriteVideo(1: UnfavoriteVideoRequest req)

    // 获取收藏视频列表
    GetFavoriteVideosResponse GetFavoriteVideos(1: GetFavoriteVideosRequest req)
}