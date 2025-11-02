#!/usr/bin/bash

WORK_DIR="$(dirname "$0")"

source "${WORK_DIR}"/functions.sh > /dev/null 2>&1

# 生成所需要的相关文件夹
ROOT_DIR="/data"

# 定义各个模块的文件夹
ETCD_DIRS=( etcd )
GATEWAY_DIRS=(gateway/mysql gateway/kafka gateway/logs)
USER_DIRS=(user/mysql user/logs)
VIDEO_DIRS=(video/redis video/mysql video/logs)
INTERACTION_DIRS=(interaction/mysql interaction/logs)
RELATION_DIRS=(relation/mysql relation/logs)

# 将所有模块的文件夹合并到一个数组中
DIRS=(
    "${ETCD_DIRS[@]}"
    "${GATEWAY_DIRS[@]}"
    "${USER_DIRS[@]}"
    "${VIDEO_DIRS[@]}"
    "${INTERACTION_DIRS[@]}"
    "${RELATION_DIRS[@]}"
)

function create_dir() {
    mkdir -p "${ROOT_DIR}"
    for file_path in "${DIRS[@]}"; do
            mkdir -p "$ROOT_DIR/$file_path"
    done
}

function delete_dir() {
    for file_path in "${DIRS[@]}"; do
        if [ -d "${ROOT_DIR:?}/${file_path:?}" ]; then
            rm -rf "${ROOT_DIR:?}/${file_path:?}"
            echo_green "Deleted: ${ROOT_DIR:?}/${file_path:?}"
        fi
    done
}

# RUN
OPTION=$1
if [[ "$OPTION" == "create" ]]; then
    create_dir
elif [[ "$OPTION" == "delete" ]]; then
    delete_dir
else
    echo_red "Only supported create or delete"
fi
