package main

import (
	"log"
	"os"
)

// 笔记服务已下线；保留入口以免旧脚本误跑，直接退出。
func main() {
	log.Println("note service is retired; use drama/commerce instead")
	os.Exit(0)
}
