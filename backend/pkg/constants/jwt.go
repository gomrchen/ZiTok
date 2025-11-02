package constants

import "time"

const (
	AccessTokenExpireTime  = 2 * 24 * time.Hour
	RefreshTokenExpireTime = 5 * 24 * time.Hour

	JwtSecret = "jwt-secret"
)
