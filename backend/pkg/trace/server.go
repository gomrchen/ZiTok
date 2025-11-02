package trace

import (
	"context"

	"github.com/bytedance/gopkg/cloud/metainfo"
	"github.com/cloudwego/kitex/pkg/endpoint"
	"github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/ext"

	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/log"
)

func ServerTraceMiddleware(serviceName string) endpoint.Middleware {
	return func(next endpoint.Endpoint) endpoint.Endpoint {
		return func(ctx context.Context, req, resp interface{}) (err error) {
			tracer, closer, _ := NewTracer(serviceName, "http://127.0.0.1:14268/api/traces", "127.0.0.1:5775")
			defer closer.Close()
			method, ok := metainfo.GetPersistentValue(ctx, constants.TracingRpcMethod)
			if !ok {
				method = "unknown method"
			}

			mdrw := &MDReaderWriter{ctx: ctx}
			spanContext, err := tracer.Extract(opentracing.TextMap, mdrw)
			if err != nil {
				log.LogrusObj.Errorf("failed when extract from tracer,error: %v\n", err)
				return err
			}

			span := tracer.StartSpan(method,
				ext.RPCServerOption(spanContext),
				opentracing.Tag{Key: string(ext.Component), Value: "kitex-server"},
				ext.SpanKindRPCServer,
			)
			defer span.Finish()

			ctx = opentracing.ContextWithSpan(ctx, span)
			err = next(ctx, req, resp)
			return err
		}
	}
}

func ServerTraceMiddleware111(tracer opentracing.Tracer) endpoint.Middleware {
	return func(next endpoint.Endpoint) endpoint.Endpoint {
		return func(ctx context.Context, req, resp interface{}) (err error) {
			method, ok := metainfo.GetValue(ctx, constants.TracingRpcMethod)
			if !ok {
				method = "unknown method"
			}

			mdrw := &MDReaderWriter{ctx: ctx}
			spanContext, err := tracer.Extract(opentracing.TextMap, mdrw)
			if err != nil {
				log.LogrusObj.Errorf("failed when extract from tracer,error: %v\n", err)
				return err
			}

			span := tracer.StartSpan(method,
				ext.RPCServerOption(spanContext),
				opentracing.Tag{Key: string(ext.Component), Value: "kitex-server"},
				ext.SpanKindRPCServer,
			)
			defer span.Finish()

			ctx = opentracing.ContextWithSpan(ctx, span)
			err = next(ctx, req, resp)
			return err
		}
	}
}
