package kafka

import (
	"sync"

	"github.com/segmentio/kafka-go"

	"github.com/pkg/errors"

	"github.com/mutezebra/tiktok/pkg/log"
)

func InitKafka(network, address string) {
	conn, err := kafka.Dial(network, address)
	if err != nil {
		log.LogrusObj.Panic(errors.Wrap(err, "connect to kafka failed, cause: %s"))
	}

	if err = conn.Close(); err != nil {
		log.LogrusObj.Panic(errors.Wrap(err, "close connection with kafka failed, cause: %s"))
	}
}

type closeIFace interface {
	Close() error
}

func closeConn(c closeIFace) func() {
	return func() {
		if err := c.Close(); err != nil {
			log.LogrusObj.Error(errors.Wrap(err, "the conn of kafka reader close failed"))
		}
	}
}

func closeAllConn(fns []func()) {
	wg := sync.WaitGroup{}
	wg.Add(len(fns))
	for i := range fns {
		fn := fns[i]
		go func() {
			fn()
			wg.Done()
		}()
	}
	wg.Wait()
}
