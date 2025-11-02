package user

import (
	"testing"

	. "github.com/smartystreets/goconvey/convey"
)

func TestService_VerifyEmail(t *testing.T) {
	srv := &Service{}
	Convey("Test VerifyEmail", t, func() {
		Convey("should return error when email = '82754'", func() {
			email := "82754"
			_, err := srv.VerifyEmail(email)
			So(err, ShouldNotBeNil)
		})

		Convey("should return nil when email = '827545521@qq.com'", func() {
			email := "827545521@qq.com"
			_, err := srv.VerifyEmail(email)
			So(err, ShouldBeNil)
		})

		Convey("should return nil when email = 'hhhhh@gmail.com'", func() {
			email := "hhhhh@gmail.com"
			_, err := srv.VerifyEmail(email)
			So(err, ShouldBeNil)
		})

		Convey("should return error when email = ''", func() {
			email := ""
			_, err := srv.VerifyEmail(email)
			So(err, ShouldNotBeNil)
		})
	})
}

func TestService_EncryptPassword(t *testing.T) {
	srv := &Service{}
	Convey("Given a password", t, func() {
		password := "apassword"
		Convey("When the password was encrypted to password_digest", func() {
			_, err := srv.EncryptPassword(password)
			Convey("Then the error should be nil", func() {
				So(err, ShouldBeNil)
			})
		})
	})
}

func TestService_CheckPassword(t *testing.T) {
	srv := &Service{}
	Convey("Given a password_digest", t, func() {
		password := "apassword"
		digest, err := srv.EncryptPassword(password)
		So(err, ShouldBeNil)
		Convey("When the digestPassword was checkout", func() {
			ok := srv.CheckPassword(password, digest)
			Convey("Then the ok should be true", func() {
				So(ok, ShouldBeTrue)
			})
		})
	})
}

func TestService_AvatarName(t *testing.T) {
	srv := &Service{}

	Convey("Test user.service`s method avtar name", t, func() {
		Convey("When pass filename='afilename',id = 45", func() {
			filename := "afilename"
			id := int64(45)
			ok, avatarName := srv.AvatarName(filename, id)
			So(ok, ShouldBeFalse)
			So(avatarName, ShouldEqual, "")
		})
		Convey("When pass filename='file.txt',id = 45", func() {
			filename := "file.txt"
			id := int64(45)
			ok, avatarName := srv.AvatarName(filename, id)
			So(ok, ShouldBeFalse)
			So(avatarName, ShouldEqual, "")
		})
		Convey("When pass filename = 'avatar.jpg',id = 45", func() {
			filename := "avatar.jpg"
			id := int64(18)
			ok, avatarName := srv.AvatarName(filename, id)
			So(ok, ShouldBeTrue)
			So(avatarName, ShouldEqual, "18.jpg")
		})
	})
}
