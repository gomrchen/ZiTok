package user

import (
	"context"
	"fmt"
	"net/mail"
	"path/filepath"
	"strings"

	"github.com/bytedance/gopkg/cloud/metainfo"

	"github.com/cloudwego/kitex/client"
	"github.com/cloudwego/kitex/pkg/transmeta"
	"github.com/cloudwego/kitex/transport"
	"github.com/pkg/errors"
	"golang.org/x/crypto/bcrypt"

	"github.com/mutezebra/tiktok/app/user/config"
	"github.com/mutezebra/tiktok/app/user/domain/model"
	"github.com/mutezebra/tiktok/app/user/domain/repository"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/interaction"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/interaction/interactionservice"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/relation"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/relation/relationservice"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/user/userservice"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/video"
	"github.com/mutezebra/tiktok/pkg/kitex_gen/api/video/videoservice"
	"github.com/mutezebra/tiktok/pkg/log"
	"github.com/mutezebra/tiktok/pkg/snowflake"
	"github.com/mutezebra/tiktok/pkg/trace"
)

type Service struct {
	Repo               repository.UserRepository
	OSS                model.OSS
	MFA                model.MFA
	Resolver           model.Resolver
	lastServiceAddress map[string]string // service_name -> service_address
}

func NewService(service *Service) *Service {
	if service.Repo == nil {
		panic("user service.Repo should not be nil")
	}
	if service.OSS == nil {
		panic("user service.OSS should not be nil")
	}
	if service.MFA == nil {
		panic("user service.MFA should not be nil")
	}
	if service.Resolver == nil {
		panic("user resolver.Resolver should not be nil")
	}
	service.lastServiceAddress = make(map[string]string)
	return service
}

func (srv *Service) GenerateID() int64 {
	return snowflake.GenerateID(config.Conf.System.WorkerID, config.Conf.System.DataCenterID)
}

func (srv *Service) EncryptPassword(password string) (string, error) {
	hashPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "nil", errors.Wrap(err, "failed to encrypt password")
	}
	result := string(hashPassword)

	return result, nil
}

func (srv *Service) CheckPassword(password string, passwordDigest string) bool {
	return bcrypt.CompareHashAndPassword([]byte(passwordDigest), []byte(password)) == nil
}

func (srv *Service) VerifyEmail(email string) (string, error) {
	_, err := mail.ParseAddress(email)
	if err != nil {
		return "", errors.Wrap(err, "invalid email format")
	}
	return email, nil
}

func (srv *Service) UploadAvatar(ctx context.Context, name string, data []byte) (err error, path string) {
	return srv.OSS.UploadAvatar(ctx, name, data)
}

func (srv *Service) DownloadAvatar(ctx context.Context, name string) (url string) {
	return srv.OSS.DownloadAvatar(ctx, name)
}

// AvatarName get the avatar filename
func (srv *Service) AvatarName(filename string, id int64) (ok bool, avatarName string) {
	ext := filepath.Ext(filename)
	imageExts := []string{".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tiff"}
	for _, imageExt := range imageExts {
		if strings.EqualFold(ext, imageExt) {
			ok = true
		}
	}
	if !ok {
		return false, ""
	}
	avatarName = fmt.Sprintf("%d%s", id, ext)
	return true, avatarName
}

func (srv *Service) GenerateTotp(userName string) (secret string, base64 string, err error) {
	return srv.MFA.GenerateTotp(userName)
}

func (srv *Service) VerifyOtp(token string, secret string) bool {
	return srv.MFA.VerifyOtp(token, secret)
}

func (srv *Service) Discovery(serviceName string) string {
	prefix := config.Conf.Etcd.ServicePrefix + config.Conf.Service[serviceName].ServiceName
	addr, err := srv.Resolver.ResolveWithPrefix(context.Background(), prefix)
	if err != nil {
		log.LogrusObj.Panic(err)
	}
	log.LogrusObj.Infof("get the %s service address %s", serviceName, addr[0])
	return addr[0]
}

var (
	userClient        userservice.Client
	videoClient       videoservice.Client
	interactionClient interactionservice.Client
	relationClient    relationservice.Client
)

func (srv *Service) GetClient(serviceName string) any {
	equal := func() bool {
		newName := srv.Discovery(serviceName)
		if _, ok := srv.lastServiceAddress[serviceName]; !ok {
			srv.lastServiceAddress[serviceName] = newName
			return false
		}
		if newName == srv.lastServiceAddress[serviceName] {
			return true
		}
		srv.lastServiceAddress[serviceName] = newName
		return false
	}

	switch serviceName {
	case constants.UserServiceName:
		if equal() {
			return userClient
		}
		srv.initClient(serviceName)
		return userClient
	case constants.VideoServiceName:
		if equal() {
			return videoClient
		}
		srv.initClient(serviceName)
		return videoClient
	case constants.InteractionServiceName:
		if equal() {
			return interactionClient
		}
		srv.initClient(serviceName)
		return interactionClient
	case constants.RelationServiceName:
		if equal() {
			return relationClient
		}
		srv.initClient(serviceName)
		return relationClient
	}
	log.LogrusObj.Panic("not supported service")
	return nil
}

func (srv *Service) initClient(serviceName string) {
	switch serviceName {
	case constants.UserServiceName:
		userClient = userservice.MustNewClient(serviceName,
			client.WithHostPorts(srv.Discovery(serviceName)),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("user-userClient")),
		)
	case constants.VideoServiceName:
		videoClient = videoservice.MustNewClient(serviceName,
			client.WithHostPorts(srv.Discovery(serviceName)),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("user-videoClient")))
	case constants.InteractionServiceName:
		interactionClient = interactionservice.MustNewClient(serviceName,
			client.WithHostPorts(srv.Discovery(serviceName)),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("user-interactionClient")))
	case constants.RelationServiceName:
		relationClient = relationservice.MustNewClient(serviceName,
			client.WithHostPorts(srv.Discovery(serviceName)),
			client.WithTransportProtocol(transport.TTHeader),
			client.WithMetaHandler(transmeta.ClientTTHeaderHandler),
			client.WithMiddleware(trace.ClientTraceMiddleware("user-relationClient")))
	}
}

func (srv *Service) GetFriendsList(ctx context.Context, uid int64) (*relation.GetFriendsListResp, error) {
	ctx = metainfo.WithPersistentValue(ctx, constants.TracingRpcMethod, "relationService.GetFriendsList")
	c := srv.GetClient(constants.RelationServiceName).(relationservice.Client)
	req := &relation.GetFriendsListReq{UID: &uid}
	return c.GetFriendsList(ctx, req)
}

func (srv *Service) GetFansList(ctx context.Context, uid int64) (*relation.GetFansListResp, error) {
	ctx = metainfo.WithPersistentValue(ctx, constants.TracingRpcMethod, "relationService.GetFansList")
	c := srv.GetClient(constants.RelationServiceName).(relationservice.Client)
	req := &relation.GetFansListReq{UID: &uid}
	return c.GetFansList(ctx, req)
}

func (srv *Service) GetFollowList(ctx context.Context, uid int64) (*relation.GetFollowListResp, error) {
	ctx = metainfo.WithPersistentValue(ctx, constants.TracingRpcMethod, "relationService.GetFollowsList")
	c := srv.GetClient(constants.RelationServiceName).(relationservice.Client)
	req := &relation.GetFollowListReq{UID: &uid}
	return c.GetFollowList(ctx, req)
}

func (srv *Service) GetVideoList(ctx context.Context, uid int64) (*video.GetVideoListResp, error) {
	ctx = metainfo.WithPersistentValue(ctx, constants.TracingRpcMethod, "videoService.GetVideoList")
	c := srv.GetClient(constants.VideoServiceName).(videoservice.Client)
	pages, size := int32(1), int8(10)
	req := &video.GetVideoListReq{
		UID:   &uid,
		Pages: &pages,
		Size:  &size,
	}
	return c.GetVideoList(ctx, req)
}

func (srv *Service) LikeList(ctx context.Context, uid int64) (*interaction.LikeListResp, error) {
	ctx = metainfo.WithPersistentValue(ctx, constants.TracingRpcMethod, "interaction.GetLikeList")
	c := srv.GetClient(constants.InteractionServiceName).(interactionservice.Client)
	pages, size := int8(1), int8(10)
	req := &interaction.LikeListReq{
		UID:      &uid,
		PageNum:  &pages,
		PageSize: &size,
	}
	return c.LikeList(ctx, req)
}
