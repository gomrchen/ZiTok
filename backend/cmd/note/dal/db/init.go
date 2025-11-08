package db

import (
	"github.com/ozline/tiktok/pkg/constants"
	"github.com/ozline/tiktok/pkg/utils"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"gorm.io/gorm/schema"
	gormopentracing "gorm.io/plugin/opentracing"
)

var DB *gorm.DB
var BaseDB *gorm.DB // 原始DB连接，用于查询其他表
var SF *utils.Snowflake

func Init() {
	var err error

	BaseDB, err = gorm.Open(mysql.Open(utils.GetMysqlDSN()),
		&gorm.Config{
			PrepareStmt:            true,
			SkipDefaultTransaction: true, // 禁用默认事务
			Logger:                 logger.Default.LogMode(logger.Info),
			NamingStrategy: schema.NamingStrategy{
				SingularTable: true, // 使用单数表名
			},
		})

	if err != nil {
		panic(err)
	}

	if err = BaseDB.Use(gormopentracing.New()); err != nil {
		panic(err)
	}

	sqlDB, err := BaseDB.DB()

	if err != nil {
		panic(err)
	}

	sqlDB.SetMaxIdleConns(constants.MaxIdleConns)       // 最大闲置连接数
	sqlDB.SetMaxOpenConns(constants.MaxConnections)     // 最大连接数
	sqlDB.SetConnMaxLifetime(constants.ConnMaxLifetime) // 最大可复用时间
	DB = BaseDB.Table(constants.NoteTableName)
	if SF, err = utils.NewSnowflake(constants.SnowflakeDatacenterID, constants.SnowflakeWorkerID); err != nil {
		panic(err)
	}
}

