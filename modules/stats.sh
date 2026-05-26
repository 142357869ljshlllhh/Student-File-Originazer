#!/bin/bash
# ============================================================
# 模块：空间统计与可视化 (stats.sh)
# 功能：分析磁盘使用情况，生成可视化统计报告
# ============================================================

source "$(dirname "$0")/utils.sh"

# 绘制 ASCII 柱状图
draw_bar() {
    local value="$1"
    local max_value="$2"
    local width="${3:-40}"
    local label="$4"

    if [ "$max_value" -eq 0 ]; then max_value=1; fi
    local bar_len=$((value * width / max_value))
    [ "$bar_len" -eq 0 ] && [ "$value" -gt 0 ] && bar_len=1

    printf "  %-25s " "$label"
    printf "│"
    printf "%${bar_len}s" | tr ' ' '█'
    printf "%$((width - bar_len))s" | tr ' ' '░'
    printf "│ %s\n" "$(human_size $value)"
}

# 统计目录大小（按一级子目录）
analyze_directory() {
    local target_dir="$1"

    if [ ! -d "$target_dir" ]; then
        print_warning "目录不存在: $target_dir"
        return
    fi

    print_info "正在分析: $target_dir"
    echo

    # 获取所有一级子目录的大小
    declare -A dir_sizes
    local total_size=0
    local max_size=0

    while IFS= read -r line; do
        local size
        size=$(echo "$line" | awk '{print $1}')
        local path
        path=$(echo "$line" | awk '{print $2}')

        # 跳过 SFO 自身
        [[ "$path" == "$SFO_ROOT"* ]] && continue

        local dirname
        dirname="$(basename "$path")"
        dir_sizes["$dirname"]=$size
        total_size=$((total_size + size))
        [ "$size" -gt "$max_size" ] && max_size=$size
    done < <(du -sk "$target_dir"/*/ 2>/dev/null | sort -k1 -rn | head -20)

    echo "──────────────────────────────────────────────────────────────"
    printf "  %-25s %s\n" "子目录" "占用空间"
    echo "──────────────────────────────────────────────────────────────"

    for dirname in "${!dir_sizes[@]}"; do
        local size="${dir_sizes[$dirname]}"
        local size_kb=$size
        draw_bar "$size_kb" "$max_size" 40 "$dirname"
    done

    echo "──────────────────────────────────────────────────────────────"
    printf "  总计占用: %s\n" "$(human_size $((total_size * 1024)))"
    echo
}

# 统计文件类型分布
analyze_file_types() {
    local target_dir="$1"

    if [ ! -d "$target_dir" ]; then
        print_warning "目录不存在: $target_dir"
        return
    fi

    print_info "正在分析文件类型分布: $target_dir"
    echo

    declare -A ext_sizes
    declare -A ext_counts

    while IFS= read -r -d '' file; do
        [ -d "$file" ] && continue
        local ext
        ext="$(get_ext "$(basename "$file")")"
        [ -z "$ext" ] && ext="无后缀"
        local size
        size="$(get_file_size "$file")"
        ext_sizes["$ext"]=$((${ext_sizes["$ext"]:-0} + size))
        ext_counts["$ext"]=$((${ext_counts["$ext"]:-0} + 1))
    done < <(find "$target_dir" -maxdepth 3 -type f -print0 2>/dev/null)

    # 按大小排序输出前15
    echo "──────────────────────────────────────────────────────────────"
    printf "  %-12s %8s %12s %s\n" "后缀" "文件数" "占用空间" "占比"
    echo "──────────────────────────────────────────────────────────────"

    local total_size=0
    for ext in "${!ext_sizes[@]}"; do
        total_size=$((total_size + ext_sizes["$ext"]))
    done
    [ "$total_size" -eq 0 ] && total_size=1

    # 排序输出
    for ext in "${!ext_sizes[@]}"; do
        echo "${ext_sizes[$ext]}|$ext|${ext_counts[$ext]}"
    done | sort -t'|' -k1 -rn | head -15 | while IFS='|' read -r size ext count; do
        local percent=$((size * 100 / total_size))
        printf "  %-12s %8d %12s %3d%%\n" ".$ext" "$count" "$(human_size $size)" "$percent"
    done

    echo "──────────────────────────────────────────────────────────────"
    printf "  总计: %d 个文件，占用 %s\n" "${#ext_sizes[@]}" "$(human_size $total_size)"
    echo
}

# 磁盘整体使用分析
analyze_disk() {
    print_title "磁盘使用概况"
    echo
    echo "──────────────────────────────────────────────────────────────"
    printf "  %-20s %8s %8s %8s %8s\n" "挂载点" "总容量" "已使用" "可用" "使用率"
    echo "──────────────────────────────────────────────────────────────"

    df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | while read -r target size used avail pcent; do
        # 跳过虚拟文件系统
        case "$target" in
            /dev|/sys|/proc|/run|/snap|/var/lib/docker|/var/lib/lxc) continue ;;
        esac
        printf "  %-20s %8s %8s %8s %6s\n" "$target" "$size" "$used" "$avail" "$pcent"
    done

    echo "──────────────────────────────────────────────────────────────"
    echo
}

# SFO 整理目录统计
analyze_sfo() {
    print_title "SFO 整理目录统计"
    echo

    if [ ! -d "$SFO_ROOT" ]; then
        print_warning "SFO 目录尚不存在"
        return
    fi

    local dirs=("$DIR_COURSEWARE" "$DIR_CODE" "$DIR_IMAGES" "$DIR_ARCHIVES" "$DIR_VIDEOS" "$DIR_MUSIC" "$DIR_OTHERS")
    local labels=("课件" "代码" "图片" "压缩包" "视频" "音乐" "其他")

    echo "──────────────────────────────────────────────────────────────"
    printf "  %-12s %8s %12s\n" "分类" "文件数" "总大小"
    echo "──────────────────────────────────────────────────────────────"

    local total_count=0
    local total_size=0

    for i in "${!dirs[@]}"; do
        local dir="${dirs[$i]}"
        local label="${labels[$i]}"
        if [ -d "$dir" ]; then
            local count
            count=$(find "$dir" -type f 2>/dev/null | wc -l)
            local size
            size=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
            size=$((size * 1024))
            total_count=$((total_count + count))
            total_size=$((total_size + size))
            printf "  %-12s %8d %12s\n" "$label" "$count" "$(human_size $size)"
        else
            printf "  %-12s %8s %12s\n" "$label" "-" "-"
        fi
    done

    echo "──────────────────────────────────────────────────────────────"
    printf "  总计: %d 个文件，占用 %s\n" "$total_count" "$(human_size $total_size)"
    echo
}

# 生成完整报告
generate_full_report() {
    local report_file="$SFO_ROOT/stats_report_$(date +%Y%m%d_%H%M%S).txt"
    local temp_file="/tmp/sfo_stats_temp_$$.txt"

    {
        echo "════════════════════════════════════════════════════════"
        echo "  空间使用统计报告"
        echo "  生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "════════════════════════════════════════════════════════"
        echo
    } > "$temp_file"

    # 磁盘概览
    {
        echo "────────────────────────────────────────────────────────"
        echo "  一、磁盘使用概况"
        echo "────────────────────────────────────────────────────────"
    } >> "$temp_file"

    df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | while read -r target size used avail pcent; do
        case "$target" in
            /dev|/sys|/proc|/run|/snap|/var/lib/docker|/var/lib/lxc) continue ;;
        esac
        printf "  %-20s %8s %8s %8s %6s\n" "$target" "$size" "$used" "$avail" "$pcent"
    done >> "$temp_file"

    # 各目标目录分析
    for dir in "${TARGET_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            {
                echo
                echo "────────────────────────────────────────────────────────"
                echo "  目录: $dir"
                echo "────────────────────────────────────────────────────────"
            } >> "$temp_file"

            du -sk "$dir"/*/ 2>/dev/null | sort -k1 -rn | head -10 | while read -r size path; do
                local dirname
                dirname="$(basename "$path")"
                printf "  %-30s %s\n" "$dirname" "$(human_size $((size * 1024)))"
            done >> "$temp_file"
        fi
    done

    # SFO 整理统计
    if [ -d "$SFO_ROOT" ]; then
        {
            echo
            echo "────────────────────────────────────────────────────────"
            echo "  SFO 整理结果统计"
            echo "────────────────────────────────────────────────────────"
        } >> "$temp_file"

        for cat_dir in "$DIR_COURSEWARE" "$DIR_CODE" "$DIR_IMAGES" "$DIR_ARCHIVES" "$DIR_VIDEOS" "$DIR_MUSIC" "$DIR_OTHERS"; do
            if [ -d "$cat_dir" ]; then
                local count
                count=$(find "$cat_dir" -type f 2>/dev/null | wc -l)
                local size
                size=$(du -sk "$cat_dir" 2>/dev/null | awk '{print $1}')
                printf "  %-20s %5d 个文件  %s\n" "$(basename "$cat_dir")" "$count" "$(human_size $((size * 1024)))"
            fi
        done >> "$temp_file"
    fi

    echo >> "$temp_file"
    echo "══════════════════════════════════════════" >> "$temp_file"

    mv "$temp_file" "$report_file"
    log "INFO" "统计报告已生成: $report_file"

    echo "$report_file"
}

# 主函数
main() {
    local action="${1:-full}"

    ensure_dirs
    check_deps || return 1

    show_banner

    case "$action" in
        full)
            print_title ">> 空间使用统计"
            echo
            analyze_disk
            analyze_sfo
            for dir in "${TARGET_DIRS[@]}"; do
                [ -d "$dir" ] && analyze_directory "$dir"
            done
            ;;
        types)
            print_title ">> 文件类型分布分析"
            echo
            for dir in "${TARGET_DIRS[@]}"; do
                [ -d "$dir" ] && analyze_file_types "$dir"
            done
            ;;
        sfo)
            print_title ">> SFO 整理统计"
            echo
            analyze_disk
            analyze_sfo
            ;;
        report)
            print_title ">> 生成空间统计报告"
            echo
            local report
            report=$(generate_full_report)
            print_success "报告已生成: $report"
            echo
            cat "$report"
            ;;
        *)
            echo "用法: $0 {full|types|sfo|report}"
            echo "  full   - 完整空间分析（默认）"
            echo "  types  - 按文件类型统计"
            echo "  sfo    - SFO 整理目录统计"
            echo "  report - 生成完整文字报告"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
