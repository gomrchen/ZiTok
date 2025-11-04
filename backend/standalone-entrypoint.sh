#!/bin/sh

SERVICE=$1
OUTPUT_PATH="./output"
CONFIG_PATH="./config/config.yaml"


function read_key() {
    local key="$2"
    local flag=0
    while read -r LINE; do
        if [[ $flag == 0 ]]; then
            if [[ "$LINE" == *"$key:"* ]]; then
                if [[ "$LINE" == *" "* ]]; then
                    echo "$LINE" | awk -F " " '{print $2}'
                    return
                else
                    continue
                fi
            fi
        fi
    done < "$1"
}

if [ -f "$CONFIG_PATH" ]; then
    export ETCD_ADDR=$(read_key "$CONFIG_PATH" "etcd-addr")
else
    if [ -z "$ETCD_ADDR" ]; then
        echo "[standalone] WARNING: ./config/config.yaml not found; defaulting ETCD_ADDR to 127.0.0.1:2379"
        export ETCD_ADDR="127.0.0.1:2379"
    else
        echo "[standalone] Using provided ETCD_ADDR=$ETCD_ADDR"
    fi
fi

if [ ! -f "$OUTPUT_PATH/$SERVICE/bootstrap.sh" ]; then
    echo "[standalone] ERROR: bootstrap.sh for service '$SERVICE' not found under $OUTPUT_PATH/$SERVICE."
    echo "[standalone] Listing $OUTPUT_PATH for diagnostics:" && ls -la "$OUTPUT_PATH" || true
    exit 1
fi

sh "$OUTPUT_PATH/$SERVICE/bootstrap.sh"