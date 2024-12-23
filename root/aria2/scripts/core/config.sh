#!/usr/bin/env bash
# /aria2/scripts/core/config.sh
# 提供配置文件加载和更新功能
set -euo pipefail

SCRIPT_CONF="/config/setting.conf"

# -----------------------------
# 加载配置文件
# -----------------------------
load_config() {
    if [[ ! -f "$SCRIPT_CONF" ]]; then
        echo "[ERROR] 配置文件不存在: $SCRIPT_CONF" >&2
        exit 1
    fi

    echo "[INFO] 加载配置文件: $SCRIPT_CONF"

    # 使用通用的方法读取每个配置项
    RMTASK=$(grep ^remove-task= "$SCRIPT_CONF" | cut -d= -f2- || echo "rmaria")
    MOVE_TASK=$(grep ^move-task= "$SCRIPT_CONF" | cut -d= -f2- || echo "false")
    CF=$(grep ^content-filter= "$SCRIPT_CONF" | cut -d= -f2- || echo "false")
    DET=$(grep ^delete-empty-dir= "$SCRIPT_CONF" | cut -d= -f2- || echo "true")
    TOR=$(grep ^handle-torrent= "$SCRIPT_CONF" | cut -d= -f2- || echo "backup-rename")
    RRT=$(grep ^remove-repeat-task= "$SCRIPT_CONF" | cut -d= -f2- || echo "true")
    MPT=$(grep ^move-paused-task= "$SCRIPT_CONF" | cut -d= -f2- || echo "false")

    # 打印加载的配置（可选，仅用于调试）
    echo "[INFO] 当前配置:"
    echo "  remove-task: $RMTASK"
    echo "  move-task: $MOVE_TASK"
    echo "  content-filter: $CF"
    echo "  delete-empty-dir: $DET"
    echo "  handle-torrent: $TOR"
    echo "  remove-repeat-task: $RRT"
    echo "  move-paused-task: $MPT"
}

# -----------------------------
# 更新配置文件
# -----------------------------
update_config() {
    echo "[INFO] 检查并更新配置文件默认值: $SCRIPT_CONF"

    # 替换每个配置项的值（如果不存在则添加默认值）
    sed -i -e "s@^remove-task=.*@remove-task=${RMTASK:-rmaria}@" "$SCRIPT_CONF"
    sed -i -e "s@^move-task=.*@move-task=${MOVE_TASK:-false}@" "$SCRIPT_CONF"
    sed -i -e "s@^content-filter=.*@content-filter=${CF:-false}@" "$SCRIPT_CONF"
    sed -i -e "s@^delete-empty-dir=.*@delete-empty-dir=${DET:-true}@" "$SCRIPT_CONF"
    sed -i -e "s@^handle-torrent=.*@handle-torrent=${TOR:-backup-rename}@" "$SCRIPT_CONF"
    sed -i -e "s@^remove-repeat-task=.*@remove-repeat-task=${RRT:-true}@" "$SCRIPT_CONF"
    sed -i -e "s@^move-paused-task=.*@move-paused-task=${MPT:-false}@" "$SCRIPT_CONF"

    # 确保不存在的键值对也被追加到配置文件中
    grep -q "^remove-task=" "$SCRIPT_CONF" || echo "remove-task=${RMTASK:-rmaria}" >>"$SCRIPT_CONF"
    grep -q "^move-task=" "$SCRIPT_CONF" || echo "move-task=${MOVE_TASK:-false}" >>"$SCRIPT_CONF"
    grep -q "^content-filter=" "$SCRIPT_CONF" || echo "content-filter=${CF:-false}" >>"$SCRIPT_CONF"
    grep -q "^delete-empty-dir=" "$SCRIPT_CONF" || echo "delete-empty-dir=${DET:-true}" >>"$SCRIPT_CONF"
    grep -q "^handle-torrent=" "$SCRIPT_CONF" || echo "handle-torrent=${TOR:-backup-rename}" >>"$SCRIPT_CONF"
    grep -q "^remove-repeat-task=" "$SCRIPT_CONF" || echo "remove-repeat-task=${RRT:-true}" >>"$SCRIPT_CONF"
    grep -q "^move-paused-task=" "$SCRIPT_CONF" || echo "move-paused-task=${MPT:-false}" >>"$SCRIPT_CONF"

    echo "[INFO] 配置文件已更新完成。"
}

# -----------------------------
# 示例调用
# -----------------------------
# 1. 在主脚本中调用 load_config() 加载配置文件
# 2. 如果需要更新默认值，调用 update_config()