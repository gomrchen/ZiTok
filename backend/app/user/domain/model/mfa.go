package model

type MFA interface {
	GenerateTotp(userName string) (secret string, base64 string, err error)
	VerifyOtp(token, secret string) bool
}
