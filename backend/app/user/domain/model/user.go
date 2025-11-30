package model

type User struct {
	ID            int64
	Username      string
	Password      string
	AvatarURL     string
	Signature     string
	Gender        int64
	Status        int64
	Birthday      string
	Email         string
	BackgroundURL string
	Token         string
	RefreshToken  string
}
