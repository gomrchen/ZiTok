package middleware

import (
	"context"

	sentinel "github.com/alibaba/sentinel-golang/api"
	"github.com/alibaba/sentinel-golang/core/flow"
	"github.com/bytedance/gopkg/util/logger"
	"github.com/cloudwego/hertz/pkg/app"
	"github.com/cloudwego/hertz/pkg/protocol/consts"
	"github.com/hertz-contrib/opensergo/sentinel/adapter"

	"github.com/mutezebra/tiktok/app/gateway/domain/model"
	"github.com/mutezebra/tiktok/pkg/constants"
)

func SentinelMW() app.HandlerFunc {
	initSentinel()
	return adapter.SentinelServerMiddleware(
		adapter.WithServerResourceExtractor(func(c context.Context, ctx *app.RequestContext) string {
			return "api"
		}),
		adapter.WithServerBlockFallback(func(ctx context.Context, c *app.RequestContext) {
			logger.Errorf("frequent requests have been rejected by the gateway. clientIP: %v\n", c.ClientIP())
			c.AbortWithStatusJSON(consts.StatusOK, map[string]interface{}{
				"code":    model.InternalServerError,
				"message": "服务器当前处于请求高峰，请稍后再试",
			})
		}),
	)
}

func initSentinel() {
	err := sentinel.InitDefault()
	if err != nil {
		logger.Fatalf("Unexpected error: %+v", err)
	}

	// limit QPS to 100
	_, err = flow.LoadRules([]*flow.Rule{
		{
			Resource:               "api",
			Threshold:              constants.SentinelThreshold,
			TokenCalculateStrategy: flow.Direct,
			ControlBehavior:        flow.Reject,
			StatIntervalInMs:       constants.SentinelStatIntervalInMs,
		},
	})
	if err != nil {
		logger.Fatalf("Unexpected error: %+v", err)
		return
	}
}
