#!/usr/bin/env bash
# scripts/actions/start.sh
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
[ -z "$JSON_RESULT" ] && { log_error "start.sh: 无法获取RPC信息"; exit 1; }
TASK_STATUS="$(get_task_status "$JSON_RESULT")"
DOWNLOAD_DIR="$(get_download_dir "$JSON_RESULT")"
INFO_HASH="$(get_info_hash "$JSON_RESULT")"

SOURCE_PATH="$FILE_PATH"
[ "$FILE_NUM" -gt 1 ] && SOURCE_PATH="$(dirname "$FILE_PATH")"

# 如果 remove-repeat-task=true，则检查目标文件夹是否已存在同名文件/目录
if [ "$RRT" = "true" ] && [ "$TASK_STATUS" != "error" ]; then
    local completed_dir="/downloads/completed"
    if [ -d "$completed_dir" ] && [ -d "$SOURCE_PATH" ]; then
        log_warn "start.sh: 发现目标文件夹中已存在同名文件/目录，尝试RPC删除重复任务..."
        remove_task_via_rpc "$TASK_GID"
        rm -rf "$SOURCE_PATH"
        # handle torrent ...
        [ -n "$INFO_HASH" ] && [ -f "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" ] && handle_torrent_file "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" "$INFO_HASH"
        exit 0
    fi
fi

log_info "start.sh: 开始任务事件处理完成"
exit 0
