package rpc

import (
	"log"

	"github.com/yxrxy/videoHub/kitex_gen/interaction/interactionservice"
	"github.com/yxrxy/videoHub/kitex_gen/notes/notesservice"
	"github.com/yxrxy/videoHub/kitex_gen/social/socialservice"
	"github.com/yxrxy/videoHub/kitex_gen/user/userservice"
	"github.com/yxrxy/videoHub/kitex_gen/video/videoservice"
	"github.com/yxrxy/videoHub/pkg/base/client"
)

var (
	userClient        userservice.Client
	videoClient       videoservice.Client
	socialClient      socialservice.Client
	interactionClient interactionservice.Client
	noteClient        notesservice.Client
)

// Init 初始化所有RPC客户端
func Init() {
	InitUserRPC()
	InitVideoRPC()
	InitSocialRPC()
	InitInteractionRPC()
	InitNoteRPC()
}

// InitNoteRPC 初始化笔记服务RPC客户端
func InitNoteRPC() {
	c, err := client.InitNoteRPC()
	if err != nil {
		log.Fatalf("初始化笔记服务客户端失败: %v", err)
	}
	noteClient = *c
}
