#!/usr/bin/bash

WORK_DIR=$(dirname "$0")
MODULE="video"
PORT="10002"

if [ -f "$WORK_DIR/functions.sh" ]; then
    source "$WORK_DIR/functions.sh" > /dev/null 2>&1
else
    echo "ERROR: $WORK_DIR/functions.sh NOT EXIST"
    exit 1
fi

CONFIG_PATHS=(video/config.yaml video/redis-pv.yaml)
MIDDLEWARE_PATHS=(video/redis.yaml)
SERVICE_PATHS=(video/video.yaml)

OPTION=$1
if [ "$OPTION" == "apply" ]; then
    fn_apply "${CONFIG_PATHS[@]}"
    fn_apply "${MIDDLEWARE_PATHS[@]}"
    fn_apply "${SERVICE_PATHS[@]}"
elif [ "$OPTION" == "create" ]; then
    fn_apply "${CONFIG_PATHS[@]}"
    fn_apply "${MIDDLEWARE_PATHS[@]}"
    wait_for_pods_running "app=tiktok-video-redis-pod" 5 100 "$MODULE"

    build_image_and_import "$MODULE" "$PORT"
    fn_apply "${SERVICE_PATHS[@]}"
elif  [ "$OPTION" == "delete" ]; then
    fn_delete "${SERVICE_PATHS[@]}"
    fn_delete "${MIDDLEWARE_PATHS[@]}"
    fn_delete "${CONFIG_PATHS[@]}"
else
    echo_red "Only supported apply, create or delete"
fi
