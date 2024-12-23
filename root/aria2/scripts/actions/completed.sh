#!/usr/bin/env bash
# scripts/actions/completed.sh
set -euo pipefail

# 1) 加载公共脚本
. "$(dirname "$0")/../core/logging.sh"
. "$(dirname "$0")/../core/config.sh"
. "$(dirname "$0")/../core/functions.sh"
. "$(dirname "$0")/../core/rpc.sh"

# 2) 获取 Aria2 传参
TASK_GID="${1:-}"
FILE_NUM="${2:-0}"
FILE_PATH="${3:-}"

# 如果没有传文件路径或文件数为0，则无需处理
if [ "$FILE_NUM" -eq 0 ] || [ -z "$FILE_PATH" ]; then
    log_info "completed.sh: 无需处理(文件数=0 or FILE_PATH为空)"
    exit 0
fi

# 3) 通过RPC获取更多信息
JSON_RESULT="$(get_rpc_result "$TASK_GID")"
if [ -z "$JSON_RESULT" ]; then
    log_error "获取RPC信息失败，可能是Aria2未启动或RPC配置有误"
    exit 1
fi
TASK_STATUS="$(get_task_status "$JSON_RESULT")"
DOWNLOAD_DIR="$(get_download_dir "$JSON_RESULT")"
INFO_HASH="$(get_info_hash "$JSON_RESULT")"

# 4) 计算实际源路径
#   若是多文件BT，通常是把最外层目录视为 SOURCE_PATH
SOURCE_PATH="$FILE_PATH"
if [ "$FILE_NUM" -gt 1 ]; then
    # 多文件，假设任务目录为  /downloads/<TASK_NAME>
    # 也可根据你原逻辑做进一步判断
    SOURCE_PATH="$(dirname "$FILE_PATH")"
fi

# 默认将完整文件移到 /downloads/completed (可在 functions.sh 里自定义)
TARGET_DIR="/downloads/completed"

# 5) 执行移动
move_file "$SOURCE_PATH" "$TARGET_DIR" "$FILE_NUM"

# 6) 处理种子文件(若存在)
#   例：如果 InfoHash 存在, 那么 torrent 文件可能是 $DOWNLOAD_DIR/$INFO_HASH.torrent
if [ -n "$INFO_HASH" ] && [ "$INFO_HASH" != "null" ]; then
    TORRENT_FILE="${DOWNLOAD_DIR}/${INFO_HASH}.torrent"
    [ -f "$TORRENT_FILE" ] && handle_torrent_file "$TORRENT_FILE" "$INFO_HASH"
fi

log_info "completed.sh: 下载完成处理结束"
exit 0
