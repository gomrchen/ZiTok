package chat

import (
	"io"

	"github.com/pkg/errors"

	"github.com/mutezebra/tiktok/pkg/constants"
	"github.com/mutezebra/tiktok/pkg/log"
)

const (
	topicName          = constants.ChatMQPersiTopicName
	partitions         = constants.ChatMQPersiTopicPartitions
	replicationFactors = constants.ChatMQPersiReplicationFactors
	readerGroup        = constants.ChatMQPersiReaderGroupName
	readerNum          = constants.ChatMQPersiReaderGroupNumber
)

// EnableMQ create the topic, start the writer, and start the consumer group
func (s *Service) EnableMQ() {
	if err := s.mq.CreateTopic(topicName, partitions, replicationFactors); err != nil {
		log.LogrusObj.Panic(errors.Wrap(err, "create topic failed"))
	}
	go s.mq.RunWriter(s.ctx, topicName, s.mqWriteCh)
	go s.mq.RunGroupReader(s.ctx, topicName, readerGroup, readerNum, s.mqReadCh)
}

// writeMsgToMQ 将message发送到mq中
func (s *Service) writeMsgToMQ(msg *Message) error {
	data, err := s.getMsgBytes(msg) // 转换成二进制格式
	if err != nil {
		return err
	}
	s.mqWriteCh <- data
	return nil
}

// readMsgFromMQ 从kafka中读取message
func (s *Service) readMsgFromMQ() (*Message, error) {
	data, ok := <-s.mqReadCh
	if !ok {
		return nil, io.EOF
	}
	return s.getMsgFromBytes(data) // 将二进制数据序列化成Message
}
