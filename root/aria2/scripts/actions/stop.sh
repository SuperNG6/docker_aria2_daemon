#!/usr/bin/env bash
# scripts/actions/stop.sh
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
[ -z "$JSON_RESULT" ] && { log_error "stop.sh: 无法获取RPC信息"; exit 1; }
TASK_STATUS="$(get_task_status "$JSON_RESULT")"
DOWNLOAD_DIR="$(get_download_dir "$JSON_RESULT")"
INFO_HASH="$(get_info_hash "$JSON_RESULT")"

SOURCE_PATH="$FILE_PATH"
[ "$FILE_NUM" -gt 1 ] && SOURCE_PATH="$(dirname "$FILE_PATH")"

# stop逻辑：根据 remove-task 配置，决定如何处理文件
if [ "$RMTASK" = "recycle" ] && [ "$TASK_STATUS" != "error" ]; then
    move_recycle "$SOURCE_PATH" "/downloads/recycle"
    [ -f "$SOURCE_PATH.aria2" ] && remove_aria2_control_file "$SOURCE_PATH"
    [ -n "$INFO_HASH" ] && [ -f "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" ] && handle_torrent_file "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" "$INFO_HASH"

elif [ "$RMTASK" = "delete" ] && [ "$TASK_STATUS" != "error" ]; then
    delete_file "$SOURCE_PATH"
    remove_aria2_control_file "$SOURCE_PATH"
    [ -n "$INFO_HASH" ] && [ -f "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" ] && handle_torrent_file "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" "$INFO_HASH"

elif [ "$RMTASK" = "rmaria" ] && [ "$TASK_STATUS" != "error" ]; then
    # 仅删除控制文件/种子文件，但不移动实体
    [ -f "$SOURCE_PATH.aria2" ] && remove_aria2_control_file "$SOURCE_PATH"
    [ -n "$INFO_HASH" ] && [ -f "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" ] && handle_torrent_file "${DOWNLOAD_DIR}/${INFO_HASH}.torrent" "$INFO_HASH"
fi

log_info "stop.sh: 已执行停止事件处理"
exit 0
