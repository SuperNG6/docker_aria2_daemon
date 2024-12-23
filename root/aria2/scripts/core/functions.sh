#!/usr/bin/env bash
# scripts/core/functions.sh
set -euo pipefail

# 依赖 config.sh, logging.sh
# 请确保在外部脚本(如事件脚本、main.sh等)中先 source config.sh && source logging.sh

DOWNLOAD_PATH="/downloads"             # 下载根目录
BAK_TORRENT_DIR="/config/backup-torrent"

CF_LOG="/config/logs/文件过滤日志.log"
MOVE_LOG="/config/logs/move.log"
DELETE_LOG="/config/logs/delete.log"
RECYCLE_LOG="/config/logs/recycle.log"

# 当移动任务文件失败时，尝试移动到此备用文件夹
FAILED_DIR="/downloads/move-failed"

# ---------------------- 内容过滤 ----------------------
delete_exclude_file() {
    local source_path="$1"
    local file_num="$2"

    # CF, DET, TOR等变量来自 setting.conf，需要你在其他脚本先执行 load_config() 进行加载
    # 当满足以下条件时才进行过滤：
    # 1) file_num > 1 (多文件任务)
    # 2) CF = true (setting.conf中 content-filter=true)
    # 3) source_path != /downloads (避免根目录误删)
    if [[ "$file_num" -gt 1 ]] && [[ -n "$CF" && "$CF" == "true" ]] && [ "${source_path}" != "${DOWNLOAD_PATH}" ]; then
        log_info "开始执行文件过滤: $source_path"
        local conf_file="/config/文件过滤.conf"
        if [ -f "$conf_file" ]; then
            local MIN_SIZE="$(grep ^min-size "$conf_file" | cut -d= -f2-)"
            local INCLUDE_FILE="$(grep ^include-file "$conf_file" | cut -d= -f2-)"
            local EXCLUDE_FILE="$(grep ^exclude-file "$conf_file" | cut -d= -f2-)"
            local KEYWORD_FILE="$(grep ^keyword-file "$conf_file" | cut -d= -f2-)"
            local INCLUDE_FILE_REGEX="$(grep ^include-file-regex "$conf_file" | cut -d= -f2-)"
            local EXCLUDE_FILE_REGEX="$(grep ^exclude-file-regex "$conf_file" | cut -d= -f2-)"

            # 按需过滤
            [[ -n ${MIN_SIZE} ]] && find "${source_path}" -type f -size -"${MIN_SIZE}" -print0 | xargs -0 rm -vf | tee -a "${CF_LOG}"
            [[ -n ${EXCLUDE_FILE} ]] && find "${source_path}" -type f -regextype posix-extended -iregex ".*\.(${EXCLUDE_FILE})" -print0 | xargs -0 rm -vf | tee -a "${CF_LOG}"
            [[ -n ${KEYWORD_FILE} ]] && find "${source_path}" -type f -regextype posix-extended -iregex ".*(${KEYWORD_FILE}).*" -print0 | xargs -0 rm -vf | tee -a "${CF_LOG}"
            [[ -n ${INCLUDE_FILE} ]] && find "${source_path}" -type f -regextype posix-extended ! -iregex ".*\.(${INCLUDE_FILE})" -print0 | xargs -0 rm -vf | tee -a "${CF_LOG}"
            [[ -n ${EXCLUDE_FILE_REGEX} ]] && find "${source_path}" -type f -regextype posix-extended -iregex "${EXCLUDE_FILE_REGEX}" -print0 | xargs -0 rm -vf | tee -a "${CF_LOG}"
            [[ -n ${INCLUDE_FILE_REGEX} ]] && find "${source_path}" -type f -regextype posix-extended ! -iregex "${INCLUDE_FILE_REGEX}" -print0 | xargs -0 rm -vf | tee -a "${CF_LOG}"
        fi

        # 如果 setting.conf 中 delete-empty-dir=true，则删除空文件夹
        if [ "${DET}" = "true" ]; then
            log_info "删除空文件夹: $source_path"
            find "${source_path}" -depth -type d -empty -exec rm -vrf {} \; | tee -a "${CF_LOG}"
        fi
    fi
}

# ---------------------- 删除 .aria2 控制文件 ----------------------
remove_aria2_control_file() {
    local source_path="$1"
    if [ -e "${source_path}.aria2" ]; then
        rm -f "${source_path}.aria2"
        log_info "已删除控制文件: ${source_path}.aria2"
    fi
}

# ---------------------- 处理种子文件 ----------------------
handle_torrent_file() {
    local torrent_file="$1"
    local task_name="$2"
    # TOR 变量来自 setting.conf 中 handle-torrent=

    case "$TOR" in
        "retain")
            # 不删除、不改名、不备份
            return
            ;;
        "delete")
            log_info "删除种子文件: ${torrent_file}"
            rm -f "${torrent_file}"
            ;;
        "rename")
            log_info "重命名种子文件: ${torrent_file} -> ${task_name}.torrent"
            mv -f "${torrent_file}" "${task_name}.torrent"
            ;;
        "backup")
            log_info "备份种子文件到: ${BAK_TORRENT_DIR}"
            mkdir -p "${BAK_TORRENT_DIR}"
            mv -f "${torrent_file}" "${BAK_TORRENT_DIR}/"
            ;;
        "backup-rename")
            log_info "重命名并备份种子文件: ${torrent_file} -> ${BAK_TORRENT_DIR}/${task_name}.torrent"
            mkdir -p "${BAK_TORRENT_DIR}"
            mv -f "${torrent_file}" "${BAK_TORRENT_DIR}/${task_name}.torrent"
            ;;
        *)
            # 默认不处理
            ;;
    esac
}

# ---------------------- 移动文件 (核心逻辑) ----------------------
move_file() {
    local source_path="$1"
    local target_path="$2"
    local file_num="$3"

    # 先删除 .aria2 + 内容过滤
    remove_aria2_control_file "$source_path"
    delete_exclude_file "$source_path" "$file_num"

    log_info "移动文件: $source_path -> $target_path"
    mkdir -p "$target_path"
    if mv -f "$source_path" "$target_path"; then
        log_info "移动成功: $source_path -> $target_path"
        echo -e "$(DATE_TIME) [INFO] 移动文件成功: $source_path -> $target_path" >> "${MOVE_LOG}"
    else
        # 第一次移动失败（例如磁盘空间不足、权限问题等）
        log_error "移动失败: $source_path -> $target_path"
        echo -e "$(DATE_TIME) [ERROR] 移动文件失败: $source_path -> $target_path" >> "${MOVE_LOG}"

        # 尝试移动到备用目录(已完成任务-移动失败)
        log_info "尝试移动到备用目录: $FAILED_DIR"
        mkdir -p "$FAILED_DIR"
        if mv -f "$source_path" "$FAILED_DIR"; then
            log_info "已移动到备用目录: $source_path -> $FAILED_DIR"
            echo -e "$(DATE_TIME) [INFO] 移动到备用目录成功: $source_path -> $FAILED_DIR" >> "${MOVE_LOG}"
        else
            log_error "移动到备用目录也失败: $source_path"
            echo -e "$(DATE_TIME) [ERROR] 移动到备用目录失败: $source_path" >> "${MOVE_LOG}"
        fi
    fi
}

# ---------------------- 删除文件 ----------------------
delete_file() {
    local source_path="$1"
    log_info "开始删除文件: $source_path"
    rm -rf "$source_path"
    if [ $? -eq 0 ]; then
        log_info "文件删除成功: $source_path"
        echo -e "$(DATE_TIME) [INFO] 文件删除成功: $source_path" >> "${DELETE_LOG}"
    else
        log_error "文件删除失败: $source_path"
        echo -e "$(DATE_TIME) [ERROR] 文件删除失败: $source_path" >> "${DELETE_LOG}"
    fi
}

# ---------------------- 移动到回收站 ----------------------
move_recycle() {
    local source_path="$1"
    local recycle_path="$2"
    log_info "移动到回收站: $source_path -> $recycle_path"
    mkdir -p "$recycle_path"
    if mv -f "$source_path" "$recycle_path"; then
        log_info "已移至回收站: $source_path"
        echo -e "$(DATE_TIME) [INFO] 成功移动文件到回收站: $source_path" >> "${RECYCLE_LOG}"
    else
        log_error "移动回收站失败: $source_path"
        echo -e "$(DATE_TIME) [ERROR] 移动文件到回收站失败: $source_path" >> "${RECYCLE_LOG}"
        # 若在回收站的移动也失败，则直接删除
        rm -rf "$source_path"
        log_info "已直接删除文件: $source_path"
    fi
}
