package router

import (
	"context"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/app/server"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
	"github.com/yxrxy/videoHub/pkg/constants"
)

func RegisterStaticRoutes(h *server.Hertz) {
	dirs := []string{
		"src/storage/videos",
		"src/storage/avatars",
		"src/storage/chat",
		"src/storage/covers",
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, constants.DirPermission); err != nil {
			log.Printf("创建目录失败 %s: %v", dir, err)
		}
	}

	// 视频单独走 Range 友好 handler，避免 iOS AVPlayer -12939
	h.GET("/videos/*filepath", serveVideoRange)

	// 按前缀挂载，Root 用 storage 根：请求 /avatars/x → src/storage/avatars/x
	// 切勿再 StaticFS("/")，否则未匹配的 /api/* 会落到 fs 并打 Error
	h.StaticFS("/avatars", &app.FS{Root: "src/storage"})
	h.StaticFS("/covers", &app.FS{Root: "src/storage"})
	h.StaticFS("/chat", &app.FS{Root: "src/storage"})

	h.NoRoute(func(ctx context.Context, c *app.RequestContext) {
		path := string(c.Path())
		if strings.HasPrefix(path, "/api/") {
			c.JSON(consts.StatusNotFound, map[string]any{
				"code":    "40400",
				"message": "not found",
			})
			return
		}
		c.Status(consts.StatusNotFound)
	})
}

func serveVideoRange(ctx context.Context, c *app.RequestContext) {
	rel := string(c.Param("filepath"))
	rel = strings.TrimPrefix(rel, "/")
	if rel == "" || strings.Contains(rel, "..") {
		c.Status(consts.StatusNotFound)
		return
	}
	full := filepath.Join("src/storage/videos", rel)
	info, err := os.Stat(full)
	if err != nil || info.IsDir() {
		c.Status(consts.StatusNotFound)
		return
	}
	f, err := os.Open(full)
	if err != nil {
		c.Status(consts.StatusInternalServerError)
		return
	}
	defer f.Close()

	size := info.Size()
	c.Response.Header.Set("Accept-Ranges", "bytes")
	c.Response.Header.Set("Content-Type", "video/mp4")
	c.Response.Header.Set("Cache-Control", "public, max-age=3600")

	rangeHdr := string(c.Request.Header.Peek("Range"))
	if rangeHdr == "" || !strings.HasPrefix(rangeHdr, "bytes=") {
		c.Response.Header.Set("Content-Length", strconv.FormatInt(size, 10))
		c.File(full)
		return
	}

	spec := strings.TrimPrefix(rangeHdr, "bytes=")
	parts := strings.SplitN(spec, "-", 2)
	start, err1 := strconv.ParseInt(parts[0], 10, 64)
	var end int64 = size - 1
	if len(parts) > 1 && parts[1] != "" {
		if v, err2 := strconv.ParseInt(parts[1], 10, 64); err2 == nil {
			end = v
		}
	}
	if err1 != nil || start < 0 || start >= size || end < start {
		c.Response.Header.Set("Content-Range", "bytes */"+strconv.FormatInt(size, 10))
		c.Status(consts.StatusRequestedRangeNotSatisfiable)
		return
	}
	if end >= size {
		end = size - 1
	}
	length := end - start + 1
	buf := make([]byte, length)
	if _, err := f.ReadAt(buf, start); err != nil {
		c.Status(consts.StatusInternalServerError)
		return
	}
	c.Response.Header.Set("Content-Range", "bytes "+strconv.FormatInt(start, 10)+"-"+strconv.FormatInt(end, 10)+"/"+strconv.FormatInt(size, 10))
	c.Response.Header.Set("Content-Length", strconv.FormatInt(length, 10))
	c.SetStatusCode(consts.StatusPartialContent)
	c.Write(buf)
}
