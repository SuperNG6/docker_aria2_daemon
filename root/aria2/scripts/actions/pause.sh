#!/usr/bin/env bash
# scripts/actions/pause.sh
set -euo pipefail

. "$(dirname "$0")/../core/logging.sh"
. "$(dirname "$0")/../core/config.sh"
. "$(dirname "$0")/../core/functions.sh"
. "$(dirname "$0")/../core/rpc.sh"

TASK_GID="${1:-}"
FILE_NUM="${2:-0}"
FILE_PATH="${3:-}"

if [ "$FILE_NUM" -eq 0 ] || [ -z "$FILE_PATH" ]; then
    exit 0
fi

JSON_RESULT="$(get_rpc_result "$TASK_GID")"
[ -z "$JSON_RESULT" ] && { log_error "pause.sh: 无法获取RPC信息"; exit 1; }

SOURCE_PATH="$FILE_PATH"
[ "$FILE_NUM" -gt 1 ] && SOURCE_PATH="$(dirname "$FILE_PATH")"

# 如果在 setting.conf 中将 move-paused-task=true，则执行移动
if [ "$MPT" = "true" ]; then
    # 这里同理，也可以仿照 completed.sh 的逻辑移动
    # 默认移动到 /downloads/paused
    local paused_dir="/downloads/paused"
    move_file "$SOURCE_PATH" "$paused_dir" "$FILE_NUM"
fi

log_info "pause.sh: 暂停事件处理结束"
exit 0
