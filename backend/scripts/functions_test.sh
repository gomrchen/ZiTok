#!/usr/bin/bash

# 为了避免 Goland 的检查, 去除黄色波浪线提示
# shellcheck disable=SC2317

WORK_DIR=$(dirname "$0")

# 只是为了获取一下 root 权限, root 权限只会用于 docker 或 kubectl/ctr 的操作上.
sudo lv > /dev/null 2>&1

if [ -f "$WORK_DIR/functions.sh" ]; then
    source "$WORK_DIR/functions.sh" > /dev/null 2>&1
else
    echo "ERROR: $WORK_DIR/functions.sh NOT EXIST"
    exit 1
fi

kubectl() {
    if [[ "$1" == "get" && "$2" == "pods" ]]; then
        printf "Pod1 Running\nPod2 Running"

    elif [[ "$1" == "get" && "$2" == "nodes" ]]; then
        echo "containerRuntimeVersion: containerd://1.6.6"
    else
        command kubectl "$@"
    fi
}

docker() {
    if [[ "$1" == "build" ]]; then
        echo "Mock docker build"
    elif [[ "$1" == "save" ]]; then
        echo "Mock docker save"
    else
        command docker "$@"
    fi
}

ctr() {
    echo "Mock ctr import"
}

# Function to assert equality
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [[ "$actual" != "$expected" ]]; then
        echo_red "Test failed: $message"
        echo_red "Expected: $expected"
        echo_red "Actual: $actual"
        exit 1
    else
        echo_green "Test passed: $message"
    fi
}

# Test whether_runtime_is_docker function
test_whether_runtime_is_docker() {
    # Mock kubectl to return containerd runtime
    local output
    output=$(whether_runtime_is_docker)
    assert_equal "true" "$output" "whether_runtime_is_docker returns true for containerd"

    # Mock kubectl to return docker runtime
    kubectl() {
        if [[ "$1" == "get" && "$2" == "nodes" ]]; then
            echo "docker://20.10.12"
        fi
    }
    local output
    output=$(whether_runtime_is_docker)
    assert_equal "false" "$output" "whether_runtime_is_docker returns false for docker"
}

# Test build_image_and_import function
test_build_image_and_import() {
    cd() {
        echo "Mock cd to $PROJECT_DIR"
    }

    whether_runtime_is_docker() {
        echo "true"
    }
    build_image_and_import "gateway" "4000"
}

TEST_FILE_PATHS=(common/etcd-pv.yaml common/initdb.yaml unexisted.yaml)

# Test fn_apply function
test_fn_apply() {
    [ -f "$DEPLOY_DIR/${TEST_FILE_PATHS[0]}" ] && return 0
    [ -f "$DEPLOY_DIR/${TEST_FILE_PATHS[1]}" ] && return 0
    [ -f "$DEPLOY_DIR/${TEST_FILE_PATHS[2]}" ] && return 1

    kubectl() {
        if [[ "$1" == "apply" ]]; then
            echo "Applied $2"
        fi
    }

    fn_apply "${TEST_FILE_PATHS[@]}"
}

# Test fn_delete function
test_fn_delete() {
    [ -f "$DEPLOY_DIR/${TEST_FILE_PATHS[0]}" ] && return 0
    [ -f "$DEPLOY_DIR/${TEST_FILE_PATHS[1]}" ] && return 0
    [ -f "$DEPLOY_DIR/${TEST_FILE_PATHS[2]}" ] && return 1

    kubectl() {
        if [[ "$1" == "delete" ]]; then
            echo "Deleted $2"
        fi
    }

    fn_delete "${TEST_FILE_PATHS[@]}"
}


# Run all tests
test_whether_runtime_is_docker
# 下面这个测试只有在你确定你拥有 go 环境的条件下测试. 因为他真的需要构建镜像
#test_build_image_and_import
test_fn_apply
test_fn_delete

echo_green "All tests passed."


