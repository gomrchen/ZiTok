package oss

import (
	"github.com/qiniu/go-sdk/v7/auth"
)

type Conf struct {
	accessKey string
	secretKey string
	domain    string
	bucket    string
}

// conf is the config of oss
var conf Conf

// InitOSS init the oss config
func InitOSS(accessKey, secretKey, domain, bucket string) {
	conf = Conf{
		accessKey: accessKey,
		secretKey: secretKey,
		domain:    domain,
		bucket:    bucket,
	}
}

// PutRet use to build a message struct that oss upload
// or download needed
type PutRet struct {
	Hash string
}

// getOSS return the oss`s max,bucket and domain
func getOSS() (mac *auth.Credentials, bucket string, domain string) {
	acK := conf.accessKey
	seK := conf.secretKey
	domain = conf.domain
	return auth.New(acK, seK), conf.bucket, domain
}
