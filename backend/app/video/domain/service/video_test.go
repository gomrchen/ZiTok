package video

import (
	"testing"

	. "github.com/smartystreets/goconvey/convey"
)

func TestService_IsImage(t *testing.T) {
	srv := &Service{}
	Convey("Test for video service`s method IsImage", t, func() {
		Convey("when pass filename = 'video.mp4'", func() {
			filename := "video.mp4"
			So(srv.IsImage(filename), ShouldBeFalse)
		})
		Convey("when pass filename = 'video.'", func() {
			filename := "video."
			So(srv.IsImage(filename), ShouldBeFalse)
		})
		Convey("when pass filename = 'image.jpgads'", func() {
			filename := "image.jpgads"
			So(srv.IsImage(filename), ShouldBeFalse)
		})
		Convey("when pass filename = 'image.jpg'", func() {
			filename := "image.jpg"
			So(srv.IsImage(filename), ShouldBeTrue)
		})
	})
}

func TestService_IsVideo(t *testing.T) {
	srv := &Service{}
	Convey("Test for video service`s method IsVideo", t, func() {
		Convey("when pass filename = 'video.mp4'", func() {
			filename := "video.mp4"
			So(srv.IsVideo(filename), ShouldBeTrue)
		})
		Convey("when pass filename = 'video.'", func() {
			filename := "video."
			So(srv.IsVideo(filename), ShouldBeFalse)
		})
		Convey("when pass filename = 'image.jpgads'", func() {
			filename := "image.jpgads"
			So(srv.IsVideo(filename), ShouldBeFalse)
		})
		Convey("when pass filename = 'image.jpg'", func() {
			filename := "image.jpg"
			So(srv.IsVideo(filename), ShouldBeFalse)
		})
	})
}
