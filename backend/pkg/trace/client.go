package trace

import (
	"context"
	"log"

	"github.com/bytedance/gopkg/cloud/metainfo"

	"github.com/mutezebra/tiktok/pkg/constants"

	"github.com/cloudwego/kitex/pkg/endpoint"
	"github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/ext"
)

func ClientTraceMiddleware(methodName string) endpoint.Middleware {
	return func(next endpoint.Endpoint) endpoint.Endpoint {
		return func(ctx context.Context, req, resp interface{}) (err error) {
			method, ok := metainfo.GetPersistentValue(ctx, constants.TracingRpcMethod)
			if !ok {
				method = "unknown method"
			}

			parentSpan := opentracing.SpanFromContext(ctx)
			tracer := parentSpan.Tracer()
			span := tracer.StartSpan(
				method,
				opentracing.ChildOf(parentSpan.Context()),
				ext.SpanKindRPCClient,
				opentracing.Tag{Key: string(ext.Component), Value: "kitex-client"},
			)
			defer span.Finish()
			md := &MDReaderWriter{ctx: ctx}
			err = tracer.Inject(span.Context(), opentracing.TextMap, md)
			if err != nil {
				log.Printf("inject-error,error:%v", err.Error())
			}

			ctx = md.ctx
			err = next(ctx, req, resp)
			return err
		}
	}
}
