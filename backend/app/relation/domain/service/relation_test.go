package relation

import (
	"fmt"
	"strings"
	"testing"

	. "github.com/smartystreets/goconvey/convey"
)

func TestService_CheckNameLength(t *testing.T) {
	srv := &Service{}
	Convey("Test CheckNameLength", t, func() {
		Convey("when pass name is 112233445566778899", func() {
			name := "112233445566778899"
			So(srv.CheckNameLength(name), ShouldBeNil)
		})
		Convey(fmt.Sprintf("when pass name is %s", strings.Repeat("好", 6)), func() {
			name := strings.Repeat("好", 6)
			So(srv.CheckNameLength(name), ShouldBeNil)
		})
		Convey(fmt.Sprintf("when pass name is %s", strings.Repeat("坏", 7)), func() {
			name := strings.Repeat("坏", 7)
			So(srv.CheckNameLength(name), ShouldNotBeNil)
		})
		Convey(fmt.Sprintf("when pass name is %s", strings.Repeat("s", 20)), func() {
			name := strings.Repeat("s", 20)
			So(srv.CheckNameLength(name), ShouldBeNil)
		})
	})
}
