/*
Copyright 2024 The west2-online Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package middleware

import (
	"context"
	"time"

	"github.com/cloudwego/kitex/pkg/endpoint"
	"github.com/cloudwego/kitex/pkg/utils/kitexutil"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

var (
	meter = otel.GetMeterProvider().Meter("videohub")

	// 请求计数器
	requestCounter, _ = meter.Int64Counter(
		"http_requests_total",
		metric.WithDescription("Total number of HTTP requests"),
	)

	// 请求持续时间
	requestDuration, _ = meter.Float64Histogram(
		"http_request_duration_seconds",
		metric.WithDescription("HTTP request duration in seconds"),
	)

	// 活跃请求数
	activeRequests, _ = meter.Int64UpDownCounter(
		"http_requests_active",
		metric.WithDescription("Number of active HTTP requests"),
	)
)

// Metrics 中间件用于记录请求指标
func Metrics() endpoint.Middleware {
	return func(next endpoint.Endpoint) endpoint.Endpoint {
		return func(ctx context.Context, req, resp interface{}) error {
			start := time.Now()

			// 增加活跃请求数
			activeRequests.Add(ctx, 1)
			defer activeRequests.Add(ctx, -1)

			// 执行请求
			err := next(ctx, req, resp)

			// 记录请求持续时间
			duration := time.Since(start).Seconds()

			// 获取服务名和方法名
			serviceName := "unknown"
			methodName := "unknown"
			if rpcInfo := ctx.Value("rpc_info"); rpcInfo != nil {
				if info, ok := rpcInfo.(interface{ GetServiceName() string }); ok {
					serviceName = info.GetServiceName()
				}
			}
			if m, ok := kitexutil.GetMethod(ctx); ok {
				methodName = m
			}

			// 设置标签
			attrs := []attribute.KeyValue{
				attribute.String("service", serviceName),
				attribute.String("method", methodName),
			}

			// 根据错误设置状态码
			status := "success"
			if err != nil {
				status = "error"
			}
			attrs = append(attrs, attribute.String("status", status))

			// 记录指标
			requestCounter.Add(ctx, 1, metric.WithAttributes(attrs...))
			requestDuration.Record(ctx, duration, metric.WithAttributes(attrs...))

			return err
		}
	}
}
