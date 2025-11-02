#!/usr/bin/bash

# 全局资源的构建
WORK_DIR="$(dirname "$0")"
MODULE="common"

source "$WORK_DIR"/functions.sh > /dev/null 2>&1

CONFIG_PATHS=(common/etcd-pv.yaml common/initdb.yaml)
POD_PATHS=(common/etcd.yaml common/jaeger.yaml common/mysql.yaml)

# RUN
OPTION=$1
if [[ "$OPTION" == "apply" ]]; then
    fn_apply "${CONFIG_PATHS[@]}"
    fn_apply "${POD_PATHS[@]}"
elif [[ "$OPTION" == "create" ]];then
    fn_apply "${CONFIG_PATHS[@]}"
    sleep 2
    fn_apply "${POD_PATHS[@]}"
    wait_for_pods_running "app=etcd-pod,app=jaeger-pod,app=mysql-pod" 5 300 "$MODULE"
elif [[ "$OPTION" == "delete" ]]; then
    fn_delete "${POD_PATHS[@]}"
    fn_delete "${CONFIG_PATHS[@]}"
else
    echo_red "Only supported apply or delete"
fi
