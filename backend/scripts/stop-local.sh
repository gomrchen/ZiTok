#!/usr/bin/env bash
set -euo pipefail

SESSION="${VIDEOHUB_TMUX_SESSION:-videohub}"
SERVICES=(user video interaction social drama commerce gateway)

for s in "${SERVICES[@]}"; do
  pkill -f "output/${s}/videohub-${s}" 2>/dev/null || true
done

tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION" || true
echo "stopped"
