#!/bin/bash

cd "$(dirname "$0")" || exit 1
cd ..

go install github.com/cloudwego/thriftgo@latest
go install github.com/cloudwego/kitex/tool/cmd/kitex@latest

kitex -module github.com/mutezebra/tiktok/pkg -gen-path ../kitex_gen base.thrift
kitex -module github.com/mutezebra/tiktok/pkg -gen-path ../kitex_gen user.thrift
kitex -module github.com/mutezebra/tiktok/pkg -gen-path ../kitex_gen video.thrift
kitex -module github.com/mutezebra/tiktok/pkg -gen-path ../kitex_gen interaction.thrift
kitex -module github.com/mutezebra/tiktok/pkg -gen-path ../kitex_gen relation.thrift

exit 0
