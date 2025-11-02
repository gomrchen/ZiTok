package log

import (
	"os"
	"strings"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
)

var LogrusObj *Logger

// InitLog initializes a logger and continuously updates its output
func InitLog(status string, system string) {
	logger := logrus.New()
	src, err := setOutPutFile(system)
	if err != nil {
		panic(err)
	}
	logger.Out = src
	if status == "debug" {
		logger.SetLevel(logrus.DebugLevel)
	} else {
		logger.SetLevel(logrus.WarnLevel)
	}

	logger.SetFormatter(&logrus.TextFormatter{
		TimestampFormat: "2006-01-02 15:04:05",
	})

	LogrusObj = &Logger{
		Logger: logger,
		pool: sync.Pool{
			New: func() any {
				return new(strings.Builder)
			},
		},
	}

	go updateLogger(system)
}

func setOutPutFile(system string) (*os.File, error) {
	now := time.Now()
	logFilePath := ""
	if dir, err := os.Getwd(); err == nil {
		if system == "windows" {
			logFilePath = dir + "\\logs\\"
		} else {
			logFilePath = dir + "/logs/"
		}
	}
	_, err := os.Stat(logFilePath)
	if os.IsNotExist(err) {
		err = os.Mkdir(logFilePath, 0o777)
		if err != nil {
			return nil, err
		}
	}
	logFileName := now.Format("2006-01-02") + ".log"
	fileName := logFilePath + logFileName
	_, err = os.Stat(fileName)
	if os.IsNotExist(err) {
		_, err = os.Create(fileName)
		if err != nil {
			return nil, err
		}
	}
	src, err := os.OpenFile(fileName, os.O_WRONLY|os.O_APPEND, os.ModeAppend)

	return src, err
}

// updateLogger update the output file for LogrusObj
func updateLogger(system string) {
	oneday := int64(3600 * 24)
	for {
		now := time.Now().Unix()
		remain := oneday - (now % oneday)
		time.Sleep(time.Duration(remain) * time.Second)

		src, err := setOutPutFile(system)
		if err != nil {
			panic(err)
		}
		LogrusObj.Out = src
	}
}
