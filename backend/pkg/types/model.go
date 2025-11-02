package types

// User is the standards for repo operand objects
type User struct {
	ID             int64  `db:"id"`
	UserName       string `db:"user_name"`
	Email          string `db:"email"`
	PasswordDigest string `db:"password_digest"`
	Gender         int8   `db:"gender"`
	Avatar         string `db:"avatar"`
	Fans           int32  `db:"fans"`
	Follows        int32  `db:"follows"`
	TotpEnable     bool   `db:"totp_enable"`
	TotpSecret     string `db:"totp_secret"`
	CreateAt       int64  `db:"create_at"`
	UpdateAt       int64  `db:"update_at"`
	DeleteAt       int64  `db:"delete_at"`
}

type Video struct {
	ID       int64  `db:"id"`
	UID      int64  `db:"uid"`
	VideoURL string `db:"video_url"`
	CoverURL string `db:"cover_url"`
	Intro    string `db:"intro"`
	Title    string `db:"title"`
	VideoExt string `db:"video_ext"`
	CoverExt string `db:"cover_ext"`
	Starts   int32  `db:"starts"`
	Likes    int32  `db:"likes"`
	Views    int32  `db:"views"`
	CreateAt int64  `db:"create_at"`
	UpdateAt int64  `db:"update_at"`
	DeleteAt int64  `db:"delete_at"`
}

type Comment struct {
	ID       int64  `db:"id"`
	UID      int64  `db:"uid"`
	VID      int64  `db:"vid"`
	RootID   int64  `db:"root_id"` // 用来标记这条评论是否是直接对视频的评论
	ReplyID  int64  `db:"reply_id"`
	Content  string `db:"content"`
	Likes    int32  `db:"likes"`
	CreateAt int64  `db:"create_at"`
	DeleteAt int64  `db:"delete_at"`
}

type Message struct {
	ID         int64  `db:"id" json:"id,omitempty"`
	UID        int64  `db:"uid" json:"uid,omitempty"`
	ReceiverID int64  `db:"receiver_id" json:"receiver_id,omitempty"`
	Content    string `db:"content" json:"content,omitempty"`
	HaveRead   bool   `db:"have_read" json:"have_read,omitempty"`
	CreateAt   int64  `db:"create_at" json:"create_at,omitempty"`
	DeleteAt   *int64 `db:"delete_at" json:"delete_at,omitempty"`
}
