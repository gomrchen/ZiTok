package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt"

	"github.com/mutezebra/tiktok/pkg/constants"
)

type Claims struct {
	UserName    string
	ID          int64
	AccessToken string
	jwt.StandardClaims
}

// CheckAndUpdateToken 用于jwt中间件里检查token并更新，如果需要更新的话
func CheckAndUpdateToken(aToken, rToken string) (claim *Claims, err error, count int) {
	claim = new(Claims)

	aClaims, err, aValid := ParseToken(aToken)
	if err != nil {
		return claim, err, count
	}
	rClaims, err, rValid := ParseToken(rToken)
	if err != nil {
		return claim, err, count
	}

	if aClaims.ID != rClaims.ID || aClaims.UserName != rClaims.UserName {
		return nil, errors.New("unsampled token"), count
	}
	claim.ID = aClaims.ID
	claim.UserName = aClaims.UserName

	// 如果两者都没过期就不更新
	if aValid && rValid {
		count = 0
		return claim, nil, count
	}

	// 如果两者都过期
	if !aValid && !rValid {
		err = errors.New("token expired,please login again")
		return claim, err, count
	}

	// 如果a过期但是r没过期就只更新a
	if !aValid && rValid {
		claim.AccessToken, err = GenerateAccessToken(aClaims.UserName, aClaims.ID)
		count = 1
		return claim, err, count
	}
	// 原则上不允许r的时间小于a的两倍，所以没有第四种情况了吧，我想
	return claim, nil, count
}

// GenerateToken 登陆时签发Token
func GenerateToken(userName string, id int64) (accessToken, refreshToken string, err error) {
	accessToken, err = GenerateAccessToken(userName, id)
	if err != nil {
		return "", "", err
	}
	refreshToken, err = GenerateRefreshToken(userName, id)
	if err != nil {
		return "", "", err
	}
	return
}

// GenerateAccessToken 签发AccessToken
func GenerateAccessToken(userName string, id int64) (accessToken string, err error) {
	timeNow := time.Now()
	accessTokenExpireTime := timeNow.Add(constants.AccessTokenExpireTime).Unix()
	claims := &Claims{
		UserName: userName,
		ID:       id,
		StandardClaims: jwt.StandardClaims{
			Issuer:    "mutezebra",
			Subject:   userName,
			ExpiresAt: accessTokenExpireTime,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	accessToken, err = token.SignedString([]byte(constants.JwtSecret))
	if err != nil {
		return "", err
	}
	return accessToken, nil
}

// GenerateRefreshToken 签发AccessToken
func GenerateRefreshToken(userName string, id int64) (refreshToken string, err error) {
	timeNow := time.Now()
	refreshTokenExpireTime := timeNow.Add(constants.RefreshTokenExpireTime).Unix()
	claims := &Claims{
		UserName: userName,
		ID:       id,
		StandardClaims: jwt.StandardClaims{
			Issuer:    "mutezebra",
			Subject:   userName,
			ExpiresAt: refreshTokenExpireTime,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	refreshToken, err = token.SignedString([]byte(constants.JwtSecret))
	if err != nil {
		return "", err
	}
	return refreshToken, nil
}

// ParseToken 解析token并判断其有没有过期
func ParseToken(token string) (*Claims, error, bool) {
	tokenClaims, err := jwt.ParseWithClaims(token, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(constants.JwtSecret), nil
	})
	if err != nil {
		return nil, err, false
	}
	claims, ok := tokenClaims.Claims.(*Claims)
	if ok && tokenClaims.Valid {
		return claims, nil, IsValid(tokenClaims)
	}
	return nil, err, false
}

func IsValid(token *jwt.Token) bool {
	return token.Valid
}
