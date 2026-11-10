#!/usr/bin/env bash
# 本地常驻启动微服务（脱离当前 shell 进程组，避免被 IDE/Agent 结束后杀掉）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SESSION="${VIDEOHUB_TMUX_SESSION:-videohub}"
SERVICES=(user video interaction social note gateway)
export ETCD_ADDR="${ETCD_ADDR:-127.0.0.1:2379}"

mkdir -p logs
mkdir -p src/storage/{videos,avatars,chat,covers}
# 静态目录访问需要索引页，避免 Hertz StaticFS 报错
for d in src/storage src/storage/*; do
  [[ -d "$d" ]] || continue
  [[ -f "$d/index.html" ]] || printf '<!doctype html><title>ok</title>\n' > "$d/index.html"
done

# 确保配置已写入 etcd
if command -v etcdctl >/dev/null 2>&1; then
  etcdctl --endpoints="$ETCD_ADDR" put /config < "$ROOT/config/config.yaml" >/dev/null || true
fi

# 清掉旧进程，避免端口占用
for s in "${SERVICES[@]}"; do
  pkill -f "output/${s}/videohub-${s}" 2>/dev/null || true
done
sleep 1

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux 未安装，请先: brew install tmux" >&2
  exit 1
fi

# 重建独立 tmux session（新会话组，不随父 shell 退出）
tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"
tmux new-session -d -s "$SESSION" -n bootstrap "echo videohub session ready; exec bash"

i=0
for s in "${SERVICES[@]}"; do
  bin="$ROOT/output/$s/videohub-$s"
  if [[ ! -x "$bin" ]]; then
    echo "缺少二进制: $bin （请先 BUILD_ONLY=1 make $s 或 bash docker/script/build.sh $s）" >&2
    exit 1
  fi
  win="vh-$s"
  if [[ $i -eq 0 ]]; then
    tmux rename-window -t "$SESSION:0" "$win"
  else
    tmux new-window -t "$SESSION" -n "$win"
  fi
  # 走 entrypoint：补齐 ETCD_ADDR / KITEX_RUNTIME_ROOT，并脱离 Agent shell 进程组
  tmux send-keys -t "$SESSION:$win" \
    "cd '$ROOT' && export SERVICE='$s' ETCD_ADDR='$ETCD_ADDR' && bash ./docker/script/entrypoint.sh 2>&1 | tee -a 'logs/$s.log'" C-m
  i=$((i + 1))
done

sleep 4
echo "started in tmux session: $SESSION"
for s in "${SERVICES[@]}"; do
  if pgrep -f "output/${s}/videohub-${s}" >/dev/null; then
    echo "  OK  $s"
  else
    echo "  FAIL $s  (see logs/$s.log / tmux capture-pane -t $SESSION:vh-$s -p)"
  fi
done

GW_PORT="$(awk '/^gateway:/{f=1} f && /addr:/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$ROOT/config/config.yaml")"
GW_PORT="${GW_PORT:-28880}"
echo "gateway: http://127.0.0.1:${GW_PORT}"
echo "attach:  tmux attach -t $SESSION"
