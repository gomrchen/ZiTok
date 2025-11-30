namespace go api.user

include "../user.thrift"

// API 服务
service UserAPI {
    // 用户账户相关接口
    user.RegisterResponse Register(1: user.RegisterRequest request) (api.post="/api/v1/user/register")

    user.PasswordResponse Password(1: user.PasswordRequest req) (api.post="/api/v1/user/password")

    user.LoginResponse Login(1: user.LoginRequest request) (api.post="/api/v1/user/login")

    user.RefreshTokenResponse RefreshToken(1: user.RefreshTokenRequest request) (api.post="/api/v1/user/token/refresh")

    // 用户信息相关接口
    user.UserInfoResponse GetUserInfo(1: user.UserInfoRequest request) (api.get="/api/v1/user/info")

    // 更新用户信息 (新增接口)
    user.UpdateUserInfoResponse UpdateUserInfo(1: user.UpdateUserInfoRequest request) (api.put="/api/v1/user/info")

    // 上传头像
    user.UploadAvatarResponse UploadAvatar(1: user.UploadAvatarRequest request) (api.post="/api/v1/user/avatar")

    // 上传背景图片 (新增接口)
    user.UploadBackgroundResponse UploadBackground(1: user.UploadBackgroundRequest request) (api.post="/api/v1/user/background")

    user.FindUsersByUsernameResponse FindUsersByUsername(1: user.FindUsersByUsernameRequest request) (api.post="/api/v1/user/username")

    user.FindUserByEmailResponse FindUserByEmail(1: user.FindUserByEmailRequest request) (api.get="/api/v1/user/email")

    // --- 收藏相关接口 ---

    // 收藏视频
    user.FavoriteVideoResponse FavoriteVideo(1: user.FavoriteVideoRequest request) (api.post="/api/v1/user/favorite")

    // 取消收藏视频
    user.UnfavoriteVideoResponse UnfavoriteVideo(1: user.UnfavoriteVideoRequest request) (api.delete="/api/v1/user/favorite/:video_id")

    // 获取收藏视频列表
    user.GetFavoriteVideosResponse GetFavoriteVideos(1: user.GetFavoriteVideosRequest request) (api.get="/api/v1/user/favorites")
}