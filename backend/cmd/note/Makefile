include ../common.mk

SERVICE_NAME = note

.PHONY: server
server:
	sh build.sh
	cd output && sh bootstrap.sh

.PHONY: gen
gen:
	kitex \
	-service "$(SERVICE_NAME)" \
	-module "$(MODULE)" \
	-I ../../idl note.thrift
	go mod tidy

.PHONY: test
client:
	cd test && go test -v

