#!/usr/bin/env bash
# scripts/core/logging.sh
set -euo pipefail

# 颜色定义
RED_FONT_PREFIX="\033[31m"
GREEN_FONT_PREFIX="\033[32m"
YELLOW_FONT_PREFIX="\033[1;33m"
LIGHT_PURPLE_FONT_PREFIX="\033[1;35m"
LIGHT_GREEN_FONT_PREFIX="\033[1;32m"
FONT_COLOR_SUFFIX="\033[0m"

# 日志前缀
INFO="[${GREEN_FONT_PREFIX}INFO${FONT_COLOR_SUFFIX}]"
ERROR="[${RED_FONT_PREFIX}ERROR${FONT_COLOR_SUFFIX}]"
WARRING="[${YELLOW_FONT_PREFIX}WARRING${FONT_COLOR_SUFFIX}]"

DATE_TIME() {
    date +"%Y/%m/%d %H:%M:%S"
}
log_info() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_error() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2
}

log_warning() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') [WARNING] $1"
}