package main

import (
	"github.com/mutezebra/tiktok/app/gateway/config"
	"github.com/mutezebra/tiktok/app/gateway/interface/persistence/database"
	"github.com/mutezebra/tiktok/app/gateway/interface/router"
	"github.com/mutezebra/tiktok/app/gateway/interface/rpc"
	"github.com/mutezebra/tiktok/pkg/kafka"
	"github.com/mutezebra/tiktok/pkg/log"
)

func main() {
	GatewayInit()

	h := router.NewRouter()

	h.Spin()
}

func GatewayInit() {
	config.InitConfig()
	log.InitLog(config.Conf.System.Status, config.Conf.System.OS)
	database.InitMysql()
	kafka.InitKafka(config.Conf.Kafka.Network, config.Conf.Kafka.Address)
	rpc.Init()
}
