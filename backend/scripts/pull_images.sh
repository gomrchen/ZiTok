#!/bin/bash

WORK_DIR="$(dirname "$0")"

source "${WORK_DIR}"/functions.sh > /dev/null 2>&1

IMAGES_FILE="images/images.txt"

# 检查 images.txt 文件是否存在
if [[ ! -f "$IMAGES_FILE" ]]; then
  echo_red "未找到 images.txt 文件！"
  exit 1
fi

# 逐行读取 images.txt 文件中的镜像名称
while IFS= read -r image; do
  if [[ -n "$image" ]]; then  # 跳过空行
    echo "正在拉取镜像: $image"
    if ! docker pull "$image"; then  # 直接检查命令的退出状态
      echo_red "错误：拉取镜像 $image 失败！"
      exit 1
    fi
  fi
done < "$IMAGES_FILE"

echo_green "所有镜像拉取完成！"
