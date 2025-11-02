#!/usr/bin/bash

WORK_DIR=$(dirname "$0")

if [ -f "$WORK_DIR/functions.sh" ]; then
    source "$WORK_DIR/functions.sh" > /dev/null 2>&1
else
    echo "ERROR: $WORK_DIR/functions.sh NOT EXIST"
    exit 1
fi

OPTION=$1

# 判断是否是支持的类型
case "$OPTION" in
    create | apply | delete)
        ;;
    *)
        echo_red "deploy.sh only supported create, apply or delete"
        exit 1
        ;;
esac

# 如果参数为 create 的话会尝试拉取镜像
if [[ "$OPTION" == "create" ]]; then
    if ! sudo sh "$WORK_DIR/pull_images.sh"; then
        echo_red "Pull images failed"
        exit 1
    fi
fi

SHELL_NAMES=(global.sh interaction.sh relation.sh user.sh video.sh gateway.sh)

# 根据不同的参数进行不同的操作. create, apply 或者是 delete
function deploy() {
    for name in "${SHELL_NAMES[@]}"; do
        echo_green "准备 $OPTION $WORK_DIR/$name"
        if [ -f "$WORK_DIR/$name" ]; then
            sh "$WORK_DIR/$name" "$OPTION"
        fi
        echo_green "成功 $OPTION $WORK_DIR/$name"
    done
}

deploy
