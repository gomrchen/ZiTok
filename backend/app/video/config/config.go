package config

import (
	"os"

	"github.com/spf13/viper"
)

var Conf *Config

type Config struct {
	System  *System             `yaml:"system"`
	Service map[string]*Service `yaml:"service"`
	Mysql   *Mysql              `yaml:"mysql"`
	Etcd    *Etcd               `yaml:"etcd"`
	QiNiu   *QiNiu              `yaml:"qiniu"`
	Redis   *Redis              `yaml:"redis"`
	Jaeger  Jaeger              `yaml:"jaeger"`
}

type System struct {
	OS           string `yaml:"os"`
	Status       string `yaml:"status"`
	WorkerID     int64  `yaml:"worker_id" mapstructure:"worker_id"`
	DataCenterID int64  `yaml:"data_center_id" mapstructure:"data_center_id"`
}

type Service struct {
	ServiceName string `yaml:"service_name" mapstructure:"service_name"`
	Address     string `yaml:"address"`
	SvcAddress  string `yaml:"svc_address" mapstructure:"svc_address"`
}

type Mysql struct {
	UserName string `yaml:"username"`
	Password string `yaml:"password"`
	Address  string `yaml:"address"`
	Database string `yaml:"database"`
	Charset  string `yaml:"charset"`
}

type Etcd struct {
	User          string `yaml:"user"`
	Password      string `yaml:"password"`
	Endpoint      string `yaml:"endpoint"`
	ServicePrefix string `yaml:"service_prefix" mapstructure:"service_prefix"`
}

type QiNiu struct {
	AccessKey         string `yaml:"access_key" mapstructure:"access_key"`
	SecretKey         string `yaml:"secret_key" mapstructure:"secret_key"`
	AvatarPath        string `yaml:"avatar_path" mapstructure:"avatar_path"`
	DefaultAvatarPath string `yaml:"default_avatar_path" mapstructure:"default_avatar_path"`
	VideoPath         string `yaml:"video_path" mapstructure:"video_path"`
	CoverPath         string `yaml:"cover_path" mapstructure:"cover_path"`
	Bucket            string `yaml:"bucket" mapstructure:"bucket"`
	Domain            string `yaml:"domain" mapstructure:"domain"`
}

type Redis struct {
	Host     string `yaml:"host" mapstructure:"host"`
	Port     string `yaml:"port" mapstructure:"port"`
	Database int    `yaml:"database" mapstructure:"database"`
	Network  string `yaml:"network" mapstructure:"network"`
	Password string `yaml:"password" mapstructure:"password"`
}

type Jaeger struct {
	CollectorEndpoint string `yaml:"collector_endpoint" mapstructure:"collector_endpoint"`
	AgentHostPort     string `yaml:"agent_host_port" mapstructure:"agent_host_port"`
}

// InitConfig initializes the configuration for the project
// and unmarshall the configuration into the global variable "Conf"
func InitConfig() {
	wd, _ := os.Getwd()

	configDIR := os.Getenv("CONFIG_DIR")
	viper.AddConfigPath(configDIR) // auto

	viper.AddConfigPath(wd + "/config/")   // linux
	viper.AddConfigPath(wd + "\\config\\") // windows
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	if err := viper.ReadInConfig(); err != nil {
		panic(err)
	}
	if err := viper.Unmarshal(&Conf); err != nil {
		panic(err)
	}
}
