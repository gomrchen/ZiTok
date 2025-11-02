package constants

// msg_type
const (
	ChatTextMessage    = 1
	HistoryChatMessage = 2
	NotReadMessage     = 3

	ChatMQReadChSize              = 10
	ChatMQWriteChSize             = 10
	ChatMQPersiTopicName          = "chat-msg-topic"
	ChatMQPersiTopicPartitions    = 10
	ChatMQPersiReplicationFactors = 1

	ChatMQPersiReaderGroupName   = "chat-msg-reader-group"
	ChatMQPersiReaderGroupNumber = 10

	ChatDefaultPersistenceGoroutineNum = 10
)
