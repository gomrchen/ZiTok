FROM golang:1.23 AS builder

ARG SERVICE

ENV TZ=Asia/Shanghai
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOPROXY=https://goproxy.cn,direct
ENV GOOS=linux
ENV GOARCH=amd64

RUN mkdir -p /app
RUN mkdir -p /app/publish

WORKDIR /app
COPY . .

RUN go mod tidy
RUN go build -ldflags="-w -s" -o ./main app/${SERVICE}/cmd/main.go

WORKDIR /app
RUN cp main publish/ && \
    cp -r app/${SERVICE}/config publish/

FROM alpine:latest

ARG SERVICE
ARG PORT

ENV TZ=Asia/Shanghai
ENV SERVICE=${SERVICE}
ENV PORT=${PORT}

RUN sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories
RUN apk update --no-cache && apk --no-cache add ca-certificates tzdata bash

WORKDIR /app

COPY --from=builder /app/publish .
RUN mkdir -p "logs"

# 指定运行时环境变量
EXPOSE ${PORT}

ENTRYPOINT ["./main"]
