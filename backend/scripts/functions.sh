#!/usr/bin/bash

cd "$(dirname "$0")" || exit1
PROJECT_DIR=$(cd .. && pwd)
DEPLOY_DIR="$PROJECT_DIR/deploy"
# shellcheck disable=SC2034
WORK_DIR="$PROJECT_DIR/scripts"

GREEN_COLOR_START="\033[32m"
RED_COLOR_START="\033[31m"
COLOR_END="\033[0m"

#$1: MESSAGE : What you want to output
function echo_green() {
    local MESSAGE=$1
    echo "$GREEN_COLOR_START $MESSAGE $COLOR_END"
}
declare -f echo_green

#$1: MESSAGE : What you want to output
function echo_red() {
    local MESSAGE=$1
    echo "$RED_COLOR_START $MESSAGE $COLOR_END"
}
declare -f echo_red

# 定义检查 Pod 状态的函数
#$1 LABEL_SELECTOR : pod 的标签
#$2 CHECK_INTERVAL : 多久运行一次检查.  默认为 5 秒
#$3 MAX_WAIT_TIME  : 最大等待时间.    默认为300秒
#$4 MODULE_NAME    : 这 个/些 pod 属于哪个 module. 默认为 unnamed module
function wait_for_pods_running() {
  local LABEL_SELECTOR=$1
  local CHECK_INTERVAL=${2:-5}  # 默认每 5 秒检查一次
  local MAX_WAIT_TIME=${3:-300} # 默认最大等待时间为 300 秒
  local MODULE_NAME=${4:-"unnamed module"}
  local WAIT_TIME=0

  echo_green "Waiting for $MODULE_NAME pods to be in Running state..."

  while true; do
    # 获取 Pod 的状态
    POD_STATUSES=$(kubectl get pods -l "$LABEL_SELECTOR" -o jsonpath='{.items[*].status.phase}')

    # 检查是否所有 Pod 都处于 Running 状态
    RUNNING_COUNT=$(echo "$POD_STATUSES" | grep -w "Running" -c)
    TOTAL_COUNT=$(echo "$POD_STATUSES" | wc -w)

    if [ "$RUNNING_COUNT" -eq "$TOTAL_COUNT" ]; then
      echo_green "All Pods with $MODULE_NAME in Running state."
      break
    fi

    # 检查是否超过最大等待时间
    if [ $WAIT_TIME -ge "$MAX_WAIT_TIME" ]; then
      echo_red "Timeout: Pods with $MODULE_NAME did not reach Running state within $MAX_WAIT_TIME seconds."
      exit 1
    fi

    # 等待 CHECK_INTERVAL 秒后再次检查
    echo "Pods are not ready yet. Retrying in $CHECK_INTERVAL seconds..."
    sleep "$CHECK_INTERVAL"
    WAIT_TIME=$((WAIT_TIME + CHECK_INTERVAL))
  done
}
declare -f wait_for_pods_running

# 判断运行时是否是 docker
function whether_runtime_is_docker() {
    local runtime
    runtime=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}')

    if [[ "$runtime" != docker://* ]]; then
        echo "true"
    else
        echo "false"
    fi
}
declare -f whether_runtime_is_docker

# 构建 Service 的镜像
#$1 module : module 的名字
#$2 port   : Expose 的端口
function build_image_and_import() {
    local module="$1"
    local port="$2"

    cd "$PROJECT_DIR" && sudo docker build -t "mutezebra/tiktok-$module:2.0" --build-arg SERVICE="$module" --build-arg PORT="$port" .

    local result
    result=$(whether_runtime_is_docker)

    if [ "$result" != "true" ]; then
        sudo docker save -o "$module.tar" "mutezebra/tiktok-$module:2.0"
        # 将 tar 格式的镜像文件导入到 k8s 中
        sudo ctr -n=k8s.io i import "$module.tar"
        rm -f "$module.tar"
    fi
}
declare -f build_image_and_import

# 应用相关配置文件
#$ file_paths : 相对于 deploy 文件夹的文件路径
function fn_apply() {
    for file_path in "$@"; do
        if [ -f "$DEPLOY_DIR/$file_path" ]; then
            sudo kubectl apply -f "$DEPLOY_DIR/$file_path"
        else
            echo_red "$DEPLOY_DIR/$file_path not exist"
        fi
    done
}
declare -f fn_apply

# 删除配置文件的应用
#$ file_paths : 相对于 deploy 文件夹的文件路径
function fn_delete() {
    for file_path in "$@"; do
        if [ -f "$DEPLOY_DIR/$file_path" ]; then
            sudo kubectl delete -f "$DEPLOY_DIR/$file_path"
        else
            echo_red "$DEPLOY_DIR/$file_path not exist"
        fi
    done
}
declare -f fn_delete
