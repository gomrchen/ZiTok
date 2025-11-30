package pack

import (
	"github.com/yxrxy/videoHub/app/user/domain/model"
	rpcmodel "github.com/yxrxy/videoHub/kitex_gen/model"
)

// User 将数据库实体转换为RPC响应实体
func User(u *model.User) *rpcmodel.User {
	if u == nil {
		return nil
	}

	// Handle optional fields
	var email, backgroundUrl, signature, birthday *string
	var gender, status *int64

	if u.Email != "" {
		email = &u.Email
	}
	if u.BackgroundURL != "" {
		backgroundUrl = &u.BackgroundURL
	}
	if u.Signature != "" {
		signature = &u.Signature
	}
	if u.Birthday != "" {
		birthday = &u.Birthday
	}
	if u.Gender != 0 {
		gender = &u.Gender
	}

	return &rpcmodel.User{
		Id:            u.ID,
		Username:      u.Username,
		Email:         email,
		Avatar:        &u.AvatarURL,
		BackgroundUrl: backgroundUrl,
		Signature:     signature,
		Gender:        gender,
		Birthday:      birthday,
		Status:        status,
	}
}
