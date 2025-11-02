package model

import "context"

type MQ interface {
	CreateTopic(topic string, partitions int, replicationFactors int) error
	RunGroupReader(ctx context.Context, topic string, groupName string, readerNumber int, ch chan []byte)
	RunWriter(ctx context.Context, topic string, ch chan []byte)
}
