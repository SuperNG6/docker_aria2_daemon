#!/usr/bin/env bash
# scripts/core/rpc.sh
set -euo pipefail

# 依赖 config.sh, logging.sh
# 需要在外部脚本中先 source config.sh && source logging.sh

# 也可以在 setting.conf 中增加相应配置
: "${SECRET:=}"                  # 若未定义则为空
: "${PORT:=6800}"               # 默认 6800
RPC_ADDRESS="localhost:${PORT}/jsonrpc"

# 获取任务状态
get_rpc_result() {
    local gid="$1"
    local rpc_payload=""
    if [[ -n "${SECRET}" ]]; then
        rpc_payload='{"jsonrpc":"2.0","method":"aria2.tellStatus","id":"NG6","params":["token:'${SECRET}'","'${gid}'"]}'
    else
        rpc_payload='{"jsonrpc":"2.0","method":"aria2.tellStatus","id":"NG6","params":["'${gid}'"]}'
    fi

    # 返回 RPC 查询结果(JSON格式)
    local result
    result=$(curl -fsSd "${rpc_payload}" "${RPC_ADDRESS}" || curl -kfsSd "${rpc_payload}" "https://${RPC_ADDRESS}")
    echo "$result"
}

# RPC 删除任务
remove_task_via_rpc() {
    local gid="$1"
    local rpc_payload=""
    if [[ -n "${SECRET}" ]]; then
        rpc_payload='{"jsonrpc":"2.0","method":"aria2.remove","id":"NG6","params":["token:'${SECRET}'","'${gid}'"]}'
    else
        rpc_payload='{"jsonrpc":"2.0","method":"aria2.remove","id":"NG6","params":["'${gid}'"]}'
    fi

    curl -fsSd "${rpc_payload}" "${RPC_ADDRESS}" || curl -kfsSd "${rpc_payload}" "https://${RPC_ADDRESS}"
}

# ========== 一些辅助函数 ==========

get_download_dir() {
    local json_data="$1"
    local dir
    dir=$(echo "$json_data" | jq -r '.result.dir' 2>/dev/null || true)
    echo "$dir"
}

get_task_status() {
    local json_data="$1"
    local status
    status=$(echo "$json_data" | jq -r '.result.status' 2>/dev/null || true)
    echo "$status"
}

get_info_hash() {
    local json_data="$1"
    local infohash
    infohash=$(echo "$json_data" | jq -r '.result.infoHash' 2>/dev/null || true)
    echo "$infohash"
}
