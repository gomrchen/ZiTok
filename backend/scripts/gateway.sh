#!/usr/bin/bash

WORK_DIR=$(dirname "$0")
MODULE="gateway"
PORT="4000"

# 判断这个文件是否存在
if [ -f "$WORK_DIR/functions.sh" ]; then
    source "$WORK_DIR/functions.sh" > /dev/null 2>&1
else
    echo "ERROR: $WORK_DIR/functions.sh NOT EXIST"
    exit 1
fi

CONFIG_PATHS=(gateway/config.yaml gateway/kafka-pv.yaml)
MIDDLEWARE_PATHS=(gateway/kafka.yaml gateway/kafka-ui.yaml)
SERVICE_PATHS=(gateway/gateway.yaml)

# 根据不同的 option 选择去如何操作
OPTION=$1
if [ "$OPTION" == "apply" ]; then
    fn_apply "${CONFIG_PATHS[@]}"
    sleep 2
    fn_apply "${MIDDLEWARE_PATHS[@]}"
    fn_apply "${SERVICE_PATHS[@]}"
elif [ "$OPTION" == "create" ]; then
    fn_apply "${CONFIG_PATHS[@]}"
    fn_apply "${MIDDLEWARE_PATHS[@]}"
    wait_for_pods_running "app=gateway-kafka-pod,app=kafka-ui" 5 100 "$MODULE"

    build_image_and_import "$MODULE" "$PORT"
    fn_apply "${SERVICE_PATHS[@]}"
elif  [ "$OPTION" == "delete" ]; then
    fn_delete "${SERVICE_PATHS[@]}"
    fn_delete "${MIDDLEWARE_PATHS[@]}"
    fn_delete "${CONFIG_PATHS[@]}"
else
    echo_red "Only supported apply, create or delete"
fi
