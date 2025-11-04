#!/bin/bash

IMAGE_NAME=${IMAGE_NAME:-registry.cn-hangzhou.aliyuncs.com/ozline/tiktok:v1}

DIR=$(cd $(dirname $0); pwd)

SERVICE_TO_START=${1:-all} # default start all

SERVICES=(api user chat follow interaction video)

# read etcd-addr from config if present
CONFIG_FILE="$DIR/config/config.yaml"
read_key() {
    local key="$2"
    while read -r LINE; do
        if [[ "$LINE" == *"$key:"* ]]; then
            if [[ "$LINE" == *" "* ]]; then
                echo "$LINE" | awk -F " " '{print $2}'
                return
            fi
        fi
    done < "$1"
}

if [ -f "$CONFIG_FILE" ]; then
    ETCD_ADDR=$(read_key "$CONFIG_FILE" "etcd-addr")
fi
ETCD_ADDR=${ETCD_ADDR:-127.0.0.1:2379}

remove_container() {
    container_status=$(docker inspect -f '{{.State.Status}}' "$1")
    if [ "$container_status" == "running" ]; then
        echo "Stopping container $1..."
        docker stop "$1"
    elif [ "$container_status" == "paused" ]; then
        echo "Unpausing and then stopping container $1..."
        docker unpause "$1"
        docker stop "$1"
    fi
    echo "Remove container $1..."
    docker rm "$1"
}

start_container() {
    echo "Starting container for $1..."
    docker run -d --name "tiktok-$1" \
    -e service=$1 \
    -e ETCD_ADDR=$ETCD_ADDR \
    --net=host \
    -v $DIR/config:/app/config \
    "$IMAGE_NAME"
}

containers_to_stop=$(docker ps -aq --filter "ancestor=$IMAGE_NAME")
if [ "$SERVICE_TO_START" == "all" ]; then
    for container_id in $containers_to_stop; do
        remove_container $container_id
    done
else
    for container_id in $containers_to_stop; do
        container_id=$(docker inspect -f '{{.Name}}' "$container_id")
        if [ "$container_id" != "/tiktok-$SERVICE_TO_START" ]; then
            continue
        fi
        remove_container $container_id
    done
fi

echo "Pulling the latest image..."
docker pull "$IMAGE_NAME"

if [ "$SERVICE_TO_START" == "all" ]; then
    for service in "${SERVICES[@]}"; do
        start_container $service
    done
else
    start_container $SERVICE_TO_START
fi