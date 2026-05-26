#!/bin/bash
# ============================================================
# 模块：重复文件检测 (duplicate.sh)
# 功能：基于 MD5 哈希检测并报告重复文件
# ============================================================

source "$(dirname "$0")/utils.sh"

# 哈希数据库文件
HASH_DB="$SFO_ROOT/.sfo_hashdb.txt"
duplicate_count=0
duplicate_size=0

# 扫描目录并构建哈希数据库
scan_files() {
    local target_dir="$1"
    local hash_db="$2"

    log "INFO" "扫描目录: $target_dir"

    if [ ! -d "$target_dir" ]; then
        log "WARN" "目录不存在，跳过: $target_dir"
        return
    fi

    while IFS= read -r -d '' file; do
        [ -d "$file" ] && continue

        local size
        size="$(get_file_size "$file")"
        local min_size=$((DUPLICATE_MIN_SIZE_KB * 1024))

        
        if [ "$size" -le 0 ]; then
            continue
        fi

        # 计算 MD5
        local md5
        md5=$(md5sum "$file" 2>/dev/null | awk '{print $1}')
        [ -z "$md5" ] && continue

        echo "$md5|$size|$file" >> "$hash_db"
    done < <(find "$target_dir" -type f -print0 2>/dev/null)
}

# 分析重复文件
analyze_duplicates() {
    local hash_db="$1"
    local report_file="$SFO_ROOT/duplicate_report_$(date +%Y%m%d_%H%M%S).txt"

    if [ ! -f "$hash_db" ] || [ ! -s "$hash_db" ]; then
        print_warning "没有扫描到任何文件"
        return
    fi

    print_info "正在分析重复文件..."

    # 按 MD5 分组，找出重复的
    local dup_hashes
    dup_hashes=$(awk -F'|' '{print $1}' "$hash_db" | sort | uniq -d)

    if [ -z "$dup_hashes" ]; then
        print_success "未发现重复文件！"
        log "INFO" "重复文件检测完成，未发现重复"
        rm -f "$hash_db"
        return
    fi

    # 生成报告
    {
        echo "════════════════════════════════════════════════════════"
        echo "  重复文件检测报告"
        echo "  生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "════════════════════════════════════════════════════════"
        echo
    } > "$report_file"

    while IFS= read -r md5; do
        local files
        files=$(grep "^$md5|" "$hash_db" | awk -F'|' '{print $3}')
        local file_count
        file_count=$(echo "$files" | wc -l)
        local file_size
        file_size=$(grep "^$md5|" "$hash_db" | head -1 | awk -F'|' '{print $2}')
        local human_sz
        human_sz=$(human_size "$file_size")
        local wasted=$((file_size * (file_count - 1)))

        {
            echo "────────────────────────────────────────────────────────"
            echo "  MD5: $md5"
            echo "  文件数: $file_count  单个大小: $human_sz  浪费空间: $(human_size $wasted)"
            echo "  文件列表:"
            echo "$files" | while IFS= read -r f; do
                echo "    - $f"
            done
            echo
        } >> "$report_file"

        duplicate_count=$((duplicate_count + file_count - 1))
        duplicate_size=$((duplicate_size + wasted))
    done <<< "$dup_hashes"

    {
        echo "════════════════════════════════════════════════════════"
        echo "  汇总: 发现 $duplicate_count 个重复文件"
        echo "  可释放空间: $(human_size $duplicate_size)"
        echo "════════════════════════════════════════════════════════"
    } >> "$report_file"

    log "INFO" "发现 $duplicate_count 个重复文件，可释放 $(human_size $duplicate_size)"
}

# 交互式删除重复文件
delete_duplicates() {
    if [ "$duplicate_count" -eq 0 ]; then
        print_info "没有重复文件可删除"
        return
    fi

    print_warning "即将处理 $duplicate_count 个重复文件（可释放 $(human_size $duplicate_size)）"

    if ! confirm "是否要删除重复文件（保留每个哈希值的第一个文件）? [y/N]"; then
        print_info "已取消删除操作"
        return
    fi

    if [ ! -f "$HASH_DB" ]; then
        print_error "哈希数据库不存在"
        return
    fi

    local deleted=0
    local dup_hashes
    dup_hashes=$(awk -F'|' '{print $1}' "$HASH_DB" | sort | uniq -d)

    while IFS= read -r md5; do
        # 跳过第一个文件（保留原件），删除其余
        grep "^$md5|" "$HASH_DB" | awk -F'|' '{print $3}' | tail -n +2 | while IFS= read -r file; do
            if rm "$file" 2>/dev/null; then
                print_success "已删除: $(basename "$file")"
                log "INFO" "删除重复文件: $file"
                ((deleted++))
            else
                print_error "删除失败: $file"
            fi
        done
    done <<< "$dup_hashes"

    print_info "共删除 $deleted 个重复文件"
    log "INFO" "删除操作完成: $deleted 个文件"
}

# 显示重复报告
show_report() {
    local latest_report
    latest_report=$(ls -t "$SFO_ROOT"/duplicate_report_*.txt 2>/dev/null | head -1)
    if [ -n "$latest_report" ] && [ -f "$latest_report" ]; then
        cat "$latest_report"
    else
        print_warning "暂无重复文件报告"
    fi
}

# 主函数
main() {
    local action="${1:-scan}"
    local target_dir="${2:-}"
    
    

    ensure_dirs
    check_deps || return 1

    show_banner
    print_title ">> 重复文件检测模块"
    echo

    case "$action" in
        scan)
            # 扫描并分析
            rm -f "$HASH_DB"
                # 强制使用传入的 target_dir，如果没有传入，则使用 $SFO_ROOT
    local scan_target="${target_dir:-$SFO_ROOT}"
    
    if [ -n "$scan_target" ]; then
        print_info "扫描指定目录: $scan_target"
        scan_files "$scan_target" "$HASH_DB"
    else
        print_error "未指定扫描目录，且 \$SFO_ROOT 为空"
        return 1
    fi
    
    analyze_duplicates "$HASH_DB"
    show_report
    ;;
        *)
            echo "用法: $0 {scan|delete|report} [目标目录]"
            echo "  scan   - 扫描并检测重复文件（默认）"
            echo "  delete - 扫描并交互删除重复文件"
            echo "  report - 查看最近一次检测报告"
            ;;
    esac

    # 清理哈希数据库
    rm -f "$HASH_DB"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
