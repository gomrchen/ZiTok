#!/bin/sh

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

# Set ETCD_ADDR from config.yaml if present; otherwise, use env or sensible default
if [ -f "$CONFIG_PATH" ]; then
    export ETCD_ADDR=$(read_key "$CONFIG_PATH" "etcd-addr")
else
    if [ -z "$ETCD_ADDR" ]; then
        echo "[entrypoint] WARNING: ./config/config.yaml not found; defaulting ETCD_ADDR to 127.0.0.1:2379"
        export ETCD_ADDR="127.0.0.1:2379"
    else
        echo "[entrypoint] Using provided ETCD_ADDR=$ETCD_ADDR"
    fi
fi

# Guard: ensure bootstrap script exists for target service
if [ ! -f "./output/${service}/bootstrap.sh" ]; then
    echo "[entrypoint] ERROR: bootstrap.sh for service '${service}' not found under ./output/${service}."
    echo "[entrypoint] Listing ./output for diagnostics:" && ls -la ./output || true
    exit 1
fi

sh ./output/${service}/bootstrap.sh