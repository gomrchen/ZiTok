#!/usr/bin/bash

WORK_DIR=$(dirname "$0")
MODULE="relation"
PORT="10004"

if [ -f "$WORK_DIR/functions.sh" ]; then
    source "$WORK_DIR/functions.sh" > /dev/null 2>&1
else
    echo "ERROR: $WORK_DIR/functions.sh NOT EXIST"
    exit 1
fi

CONFIG_PATHS=(relation/config.yaml)
SERVICE_PATHS=(relation/relation.yaml)

OPTION=$1
if [ "$OPTION" == "apply" ]; then
    fn_apply "${CONFIG_PATHS[@]}"
    fn_apply "${SERVICE_PATHS[@]}"
elif [ "$OPTION" == "create" ]; then
    fn_apply "${CONFIG_PATHS[@]}"
    build_image_and_import "$MODULE" "$PORT"
    fn_apply "${SERVICE_PATHS[@]}"
elif  [ "$OPTION" == "delete" ]; then
    fn_delete "${SERVICE_PATHS[@]}"
    fn_delete "${CONFIG_PATHS[@]}"
else
    echo_red "Only supported apply, create or delete"
fi
