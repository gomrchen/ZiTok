package database

import (
	"database/sql"
	"fmt"
	"time"

	_ "github.com/go-sql-driver/mysql"

	"github.com/mutezebra/tiktok/app/user/config"
	"github.com/mutezebra/tiktok/pkg/log"
)

var _db *sql.DB

func InitMysql() {
	conf := config.Conf.Mysql
	dsn := fmt.Sprintf("%s:%s@tcp(%s)/%s?charset=%s&parseTime=true&loc=Local", conf.UserName, conf.Password, conf.Address, conf.Database, conf.Charset)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.LogrusObj.Panic(err)
	}
	if err = db.Ping(); err != nil {
		log.LogrusObj.Panic(err)
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(5 * time.Minute)
	_db = db
}
