#!/bin/bash
# ============================================================
# 模块：安全备份与恢复 (backup.sh)
# 功能：操作前自动备份，支持一键恢复
# ============================================================

source "$(dirname "$0")/utils.sh"

# 创建备份
create_backup() {
    local backup_name="${1:-}"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    if [ -z "$backup_name" ]; then
        backup_name="backup_${timestamp}"
    fi

    local backup_path="$BACKUP_DIR/$backup_name"
    mkdir -p "$backup_path"

    print_info "正在创建备份..."
    log "INFO" "开始创建备份: $backup_name"

    local manifest_file="$backup_path/manifest.txt"
    local total_files=0
    local total_size=0

    {
        echo "备份清单"
        echo "备份名称: $backup_name"
        echo "创建时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "================================================"
        echo
    } > "$manifest_file"

    # 备份每个目标目录
    for dir in "${TARGET_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            log "WARN" "目录不存在，跳过备份: $dir"
            continue
        fi

        local dir_basename
        dir_basename="$(basename "$dir")"
        local dest_dir="$backup_path/$dir_basename"

        print_info "  备份: $dir -> $dest_dir"

        # 复制文件（保留目录结构）
        mkdir -p "$dest_dir"

        while IFS= read -r -d '' file; do
            [ -d "$file" ] && continue
            [[ "$file" == "$SFO_ROOT"* ]] && continue

            local rel_path="${file#$dir/}"
            local dest_file="$dest_dir/$rel_path"
            local dest_parent
            dest_parent="$(dirname "$dest_file")"

            mkdir -p "$dest_parent"

            if cp "$file" "$dest_file" 2>/dev/null; then
                local size
                size="$(get_file_size "$file")"
                echo "$rel_path|$size" >> "$manifest_file"
                total_files=$((total_files + 1))
                total_size=$((total_size + size))
            else
                log "ERROR" "备份失败: $file"
            fi
        done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)
    done

    {
        echo
        echo "================================================"
        echo "总计文件: $total_files"
        echo "总计大小: $(human_size $total_size)"
    } >> "$manifest_file"

    # 创建压缩包
    print_info "正在压缩备份..."
    local tar_file="$BACKUP_DIR/${backup_name}.tar.gz"
    (
        cd "$backup_path" && tar -czf "$tar_file" . 2>/dev/null
    )

    if [ -f "$tar_file" ]; then
        print_success "备份已创建: $tar_file"
        print_info "文件数: $total_files  总大小: $(human_size $total_size)"
        log "INFO" "备份完成: $tar_file ($total_files 文件, $(human_size $total_size))"
        # 清理未压缩的临时目录
        rm -rf "$backup_path"
    else
        print_warning "压缩失败，保留原始备份目录: $backup_path"
    fi

    # 清理旧备份
    clean_old_backups
}

# 列出所有备份
list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "暂无备份"
        return
    fi

    echo
    print_title "现有备份列表："
    echo "──────────────────────────────────────────────────────────────"
    printf "  %-4s %-22s %10s %s\n" "序号" "时间" "大小" "文件名"
    echo "──────────────────────────────────────────────────────────────"

    local index=0
    local backups=()
    while IFS= read -r -d '' file; do
        ((index++))
        local basename
        basename="$(basename "$file")"
        local size
        size=$(stat -c %s "$file" 2>/dev/null || echo 0)
        local mtime
        mtime=$(stat -c %y "$file" 2>/dev/null | cut -d'.' -f1 || echo "未知")
        printf "  %-4d %-22s %10s %s\n" "$index" "$mtime" "$(human_size $size)" "$basename"
        backups+=("$file")
    done < <(find "$BACKUP_DIR" -name "*.tar.gz" -print0 2>/dev/null | sort -z)

    if [ "$index" -eq 0 ]; then
        print_info "暂无备份"
    else
        echo "──────────────────────────────────────────────────────────────"
        echo "  共 $index 个备份"
    fi

    # 返回备份数组（用换行分隔）
    printf '%s\n' "${backups[@]}"
}

# 恢复备份
restore_backup() {
    local backup_file="$1"

    if [ -z "$backup_file" ]; then
        # 交互式选择备份
        print_title "选择要恢复的备份："
        echo

        local backups
        mapfile -t backups < <(list_backups)

        if [ ${#backups[@]} -eq 0 ]; then
            print_warning "没有可用的备份"
            return
        fi

        echo
        read -r -p "请输入序号 [1-${#backups[@]}]: " choice

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
            print_error "无效选择"
            return
        fi

        backup_file="${backups[$((choice - 1))]}"
    fi

    if [ ! -f "$backup_file" ]; then
        print_error "备份文件不存在: $backup_file"
        return 1
    fi

    print_warning "恢复操作将覆盖当前目标目录中的文件"
    if ! confirm "确认恢复备份 $(basename "$backup_file")? [y/N]"; then
        print_info "已取消恢复"
        return
    fi

    print_info "正在恢复备份..."
    log "INFO" "开始恢复备份: $backup_file"

    local restore_dir="$BACKUP_DIR/restore_temp_$$"
    mkdir -p "$restore_dir"

    # 解压备份
    if tar -xzf "$backup_file" -C "$restore_dir" 2>/dev/null; then
        print_info "备份已解压到临时目录"
    else
        print_error "解压失败"
        rm -rf "$restore_dir"
        return 1
    fi

    # 恢复文件到目标目录
    local restored=0
    for dir in "${TARGET_DIRS[@]}"; do
        local dir_basename
        dir_basename="$(basename "$dir")"
        if [ -d "$restore_dir/$dir_basename" ]; then
            cp -r "$restore_dir/$dir_basename"/* "$dir/" 2>/dev/null
            local count
            count=$(find "$restore_dir/$dir_basename" -type f 2>/dev/null | wc -l)
            restored=$((restored + count))
            print_success "恢复 $dir_basename: $count 个文件"
        fi
    done

    # 清理
    rm -rf "$restore_dir"

    print_success "备份恢复完成！共恢复 $restored 个文件"
    log "INFO" "备份恢复完成: $backup_file -> $restored 文件"
}

# 清理旧备份
clean_old_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        return
    fi

    # 只保留最近 N 个备份
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -name "*.tar.gz" 2>/dev/null | wc -l)

    if [ "$backup_count" -gt "$BACKUP_KEEP_COUNT" ]; then
        log "INFO" "清理旧备份（保留最近 $BACKUP_KEEP_COUNT 个）"

        find "$BACKUP_DIR" -name "*.tar.gz" -print0 2>/dev/null | \
            xargs -0 ls -t | \
            tail -n +$((BACKUP_KEEP_COUNT + 1)) | \
            while IFS= read -r file; do
                print_info "删除旧备份: $(basename "$file")"
                rm -f "$file"
                log "INFO" "删除旧备份: $file"
            done
    fi
}

# 快速备份（仅备份文件列表，不复制内容）
quick_snapshot() {
    local snapshot_file="$BACKUP_DIR/snapshot_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "文件快照"
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "================================================"
        echo
    } > "$snapshot_file"

    for dir in "${TARGET_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then continue; fi
        echo "--- $dir ---" >> "$snapshot_file"
        find "$dir" -maxdepth 1 -type f -printf '%p|%s|%T+\n' 2>/dev/null >> "$snapshot_file"
        echo >> "$snapshot_file"
    done

    print_success "文件快照已保存: $snapshot_file"
    log "INFO" "文件快照已创建: $snapshot_file"
}

# 主函数
main() {
    local action="${1:-backup}"
    local target="${2:-}"

    ensure_dirs
    check_deps || return 1

    show_banner

    case "$action" in
        backup)
            print_title ">> 安全备份模块"
            echo
            create_backup "$target"
            ;;
        list)
            list_backups
            ;;
        restore)
            print_title ">> 备份恢复模块"
            echo
            restore_backup "$target"
            ;;
        snapshot)
            print_title ">> 文件快照"
            echo
            quick_snapshot
            ;;
        clean)
            print_title ">> 清理旧备份"
            echo
            clean_old_backups
            print_success "清理完成"
            ;;
        *)
            echo "用法: $0 {backup|list|restore|snapshot|clean}"
            echo "  backup   - 创建完整备份（默认）"
            echo "  list     - 列出所有备份"
            echo "  restore  - 恢复备份"
            echo "  snapshot - 创建文件列表快照"
            echo "  clean    - 清理旧备份"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
