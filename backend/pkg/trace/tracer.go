package trace

import (
	"context"
	"io"

	"github.com/opentracing/opentracing-go"
	"github.com/uber/jaeger-client-go"
	jaegercfg "github.com/uber/jaeger-client-go/config"

	"github.com/mutezebra/tiktok/pkg/constants"
)

func NewTracer(serviceName string, colEnp, agentEnp string) (opentracing.Tracer, io.Closer, error) {
	cfg := jaegercfg.Configuration{
		ServiceName: serviceName,
		Sampler: &jaegercfg.SamplerConfig{
			Type:  jaeger.SamplerTypeConst,
			Param: 1,
		},
		Reporter: &jaegercfg.ReporterConfig{
			LogSpans: true,
		},
	}
	if serviceName == constants.GatewayServiceKey {
		cfg.Reporter.CollectorEndpoint = colEnp
	} else {
		cfg.Reporter.LocalAgentHostPort = agentEnp
	}

	return cfg.NewTracer()
}

type Tags interface {
	SetSpanType(s string)
	SetKV(k string, v interface{})
	SetKVS(kvs map[string]interface{})
	GetSpanType() string
	GetTags() map[string]interface{}
}

type tags struct {
	spanType string
	kvs      map[string]interface{}
}

func NewTags() Tags {
	return &tags{
		spanType: "",
		kvs:      make(map[string]interface{}),
	}
}

func (t *tags) SetSpanType(s string) {
	t.spanType = s
}

func (t *tags) SetKV(k string, v interface{}) {
	t.kvs[k] = v
}

func (t *tags) DelKV(k string) {
	delete(t.kvs, k)
}

func (t *tags) SetKVS(kvs map[string]interface{}) {
	for k, v := range kvs {
		t.kvs[k] = v
	}
}

func (t *tags) GetSpanType() string {
	return t.spanType
}

func (t *tags) GetTags() map[string]interface{} {
	m := make(map[string]interface{}, len(t.kvs))
	for k, v := range t.kvs {
		m[k] = v
	}
	return m
}

func NewSpan(ctx context.Context, operationName string, tags Tags) opentracing.Span {
	parentSpan := opentracing.SpanFromContext(ctx)
	childSpan := parentSpan.Tracer().StartSpan(operationName, opentracing.ChildOf(parentSpan.Context()))

	if tags != nil {
		for k, v := range tags.GetTags() {
			childSpan.SetTag(k, v)
		}

		if tags.GetSpanType() == "" {
			childSpan.SetTag("span_type", "unknown span type")
		} else {
			childSpan.SetTag("span_type", tags.GetSpanType())
		}
	}

	return childSpan
}
