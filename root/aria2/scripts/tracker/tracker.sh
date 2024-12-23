#!/usr/bin/env bash
# scripts/tracker/tracker.sh
# 合并原先 "rpc_tracker.sh" 与 "tracker.sh" 的功能

set -euo pipefail

# 这里引用你已有的公共脚本(若需要日志、配置、RPC等)
# . "$(dirname "$0")/../core/logging.sh"
# . "$(dirname "$0")/../core/config.sh"
# . "$(dirname "$0")/../core/rpc.sh"

DOWNLOADER="curl -fsSL --connect-timeout 3 --max-time 3 --retry 2"

# 如果要通过RPC的方式给 Aria2 添加Tracker，需要先知道RPC地址
: "${SECRET:=}"                  # 环境变量/从 config.sh 获取
: "${PORT:=6800}"
RPC_ADDRESS="localhost:${PORT}/jsonrpc"

# Aria2配置文件(若需要往这里写入tracker)
ARIA2_CONF="/config/aria2.conf"

# ---------------------获取Trackers列表------------------------
get_trackers() {
    # 如果用户想自定义 Tracker URL，可用环境变量CTU传入
    local ctu="${CTU:-}"

    local tracker_data=""
    if [[ -z "${ctu}" ]]; then
        echo "[INFO] 没有提供自定义CTU，使用默认来源获取 BT-Trackers ..."
        tracker_data=$(
            $DOWNLOADER https://trackerslist.com/all_aria2.txt ||
            $DOWNLOADER https://cdn.jsdelivr.net/gh/XIU2/TrackersListCollection@master/all_aria2.txt ||
            $DOWNLOADER https://ghp.ci/https://raw.githubusercontent.com/XIU2/TrackersListCollection/master/all_aria2.txt
        )
    else
        echo "[INFO] 从CTU指定URL获取BT trackers: $ctu"
        local IFS=","
        for url in $ctu; do
            # 追加
            tracker_data+="$($DOWNLOADER "$url" | tr ',' '\n')"
            tracker_data+=$'\n'
        done
        # 去重并转为逗号分隔
        tracker_data=$(echo "$tracker_data" | awk NF | sort -u | sed 'H;1h;$!d;x;y/\n/,/')
    fi

    if [[ -z "${tracker_data}" ]]; then
        echo "[ERROR] 无法获取Trackers，可能网络故障或链接无效"
        exit 1
    fi

    echo "$tracker_data"
}

# ---------------------通过RPC更新Global BT-Tracker------------------------
add_trackers_rpc() {
    local trackers="$1"

    echo "[INFO] 通过RPC添加BT-Tracker到 Aria2: ${RPC_ADDRESS}"
    local rpc_payload

    if [[ -n "$SECRET" ]]; then
        rpc_payload='{"jsonrpc":"2.0","method":"aria2.changeGlobalOption","id":"NG6","params":["token:'${SECRET}'",{"bt-tracker":"'${trackers}'"}]}'
    else
        rpc_payload='{"jsonrpc":"2.0","method":"aria2.changeGlobalOption","id":"NG6","params":[{"bt-tracker":"'${trackers}'"}]}'
    fi

    local result
    result=$(curl -fsSd "${rpc_payload}" "${RPC_ADDRESS}" || curl -kfsSd "${rpc_payload}" "https://${RPC_ADDRESS}")
    if echo "$result" | grep -q "OK"; then
        echo "[INFO] 成功通过RPC更新BT-Tracker！"
    else
        echo "[ERROR] RPC接口错误或网络故障，无法更新BT-Tracker"
    fi
}

# ---------------------写入 aria2.conf------------------------
add_trackers_conf() {
    local trackers="$1"

    echo "[INFO] 添加BT-Tracker到配置文件: ${ARIA2_CONF}"
    if [ ! -f "$ARIA2_CONF" ]; then
        echo "[ERROR] 找不到 $ARIA2_CONF"
        exit 1
    fi

    if ! grep -q "bt-tracker=" "$ARIA2_CONF"; then
        # 如果配置文件里没有这行，就先补一行
        echo "bt-tracker=" >> "$ARIA2_CONF"
    fi

    # 用sed修改
    sed -i "s@^\(bt-tracker=\).*@\1${trackers}@" "$ARIA2_CONF"
    echo "[INFO] 已成功将BT-Tracker写入 ${ARIA2_CONF}"
}

# ---------------------主流程------------------------
main() {
    # 先获取新的Trackers
    local trackers
    trackers="$(get_trackers)"

    echo -e "\n--------------------[BitTorrent Trackers]--------------------"
    echo "$trackers"
    echo -e "-------------------------------------------------------------\n"

    # 如果用户希望使用 RPC 方式更新，则可以执行:
    # add_trackers_rpc "$trackers"
    #
    # 如果用户希望写入 aria2.conf，则可以执行:
    # add_trackers_conf "$trackers"

    # 你也可以根据传入参数决定要执行哪种操作，比如:
    case "${1:-}" in
        rpc)
            add_trackers_rpc "$trackers"
            ;;
        conf)
            add_trackers_conf "$trackers"
            ;;
        both)
            add_trackers_rpc "$trackers"
            add_trackers_conf "$trackers"
            ;;
        *)
            echo "Usage: $0 [rpc|conf|both]"
            echo "默认仅打印Trackers，可带参数更新"
            ;;
    esac
}

main "$@"
