package rpc

import (
	"github.com/yxrxy/videoHub/kitex_gen/interaction/interactionservice"
	"github.com/yxrxy/videoHub/kitex_gen/social/socialservice"
	"github.com/yxrxy/videoHub/kitex_gen/user/userservice"
	"github.com/yxrxy/videoHub/kitex_gen/video/videoservice"
)

var (
	userClient        userservice.Client
	videoClient       videoservice.Client
	socialClient      socialservice.Client
	interactionClient interactionservice.Client
)

// Init 初始化所有RPC客户端（笔记服务已下线；Drama/Commerce 软降级）
func Init() {
	InitUserRPC()
	InitVideoRPC()
	InitSocialRPC()
	InitInteractionRPC()
	InitDramaRPC()
	InitCommerceRPC()
}
