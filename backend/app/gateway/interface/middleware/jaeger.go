package middleware

import (
	"context"

	"github.com/cloudwego/hertz/pkg/app"
	"github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/ext"

	"github.com/mutezebra/tiktok/app/gateway/config"
	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/log"
	"github.com/mutezebra/tiktok/pkg/trace"
)

func TraceMiddleware() app.HandlerFunc {
	return func(ctx context.Context, c *app.RequestContext) {
		tracer, closer, err := trace.NewTracer(constants.GatewayServiceKey, config.Conf.Jaeger.CollectorEndpoint, config.Conf.Jaeger.AgentHostPort)
		if err != nil {
			log.LogrusObj.Errorf("failed when get tracer,error: %v", err)
			return
		}
		defer closer.Close()

		startSpan := tracer.StartSpan(string(c.Request.URI().Path()))
		defer startSpan.Finish()

		ext.HTTPUrl.Set(startSpan, string(c.Request.URI().Path()))
		ext.HTTPMethod.Set(startSpan, string(c.Request.Method()))
		ext.Component.Set(startSpan, "gateway")

		ctx = opentracing.ContextWithSpan(ctx, startSpan)
		c.Next(ctx)
		ext.HTTPStatusCode.Set(startSpan, uint16(c.Response.StatusCode()))
	}
}
