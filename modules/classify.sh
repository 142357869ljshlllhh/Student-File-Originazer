#!/bin/bash
# ============================================================
# 模块：文件智能分类 (classify.sh)
# 功能：先按后缀进行一级分类，再按规则进行二级归档
# ============================================================

source "$(dirname "$0")/utils.sh"

# 分类统计
declare -A classify_stats
total_moved=0
total_skipped=0

# 执行分类
run_classify() {
    local target_dir="$1"
    local dry_run="${2:-false}"

    log "INFO" "开始分类目录: $target_dir"

    if [ ! -d "$target_dir" ]; then
        log "WARN" "目录不存在，跳过: $target_dir"
        return
    fi

    # 构建排除参数
    local exclude_args=()
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        exclude_args+=(-not -name "$pattern")
    done

    # 遍历目标目录中的文件
    while IFS= read -r -d '' file; do
        # 跳过目录
        [ -d "$file" ] && continue
        # 跳过 SFO 自身目录
        [[ "$file" == "$SFO_ROOT"* ]] && continue

        local filename
        filename="$(basename "$file")"
        local category_dir
        category_dir="$(get_classify_target_dir "$file")"
        local category_label="${category_dir#"$SFO_ROOT"/}"

        if [ "$dry_run" = true ]; then
            print_info "[预览] $file -> $category_label/"
            ((total_moved++))
            continue
        fi

        # 执行移动
        local new_path
        if new_path=$(safe_move "$file" "$category_dir"); then
            print_success "$filename -> $category_label/"
            log "INFO" "移动: $file -> $new_path"
            ((total_moved++))
            classify_stats["$category_label"]=$((${classify_stats["$category_label"]:-0} + 1))
        else
            print_error "移动失败: $filename"
            log "ERROR" "移动失败: $file"
            ((total_skipped++))
        fi
    done < <(find "$target_dir" -maxdepth 1 -type f "${exclude_args[@]}" -print0 2>/dev/null)
}

# 显示分类统计
show_classify_stats() {
    echo
    echo "════════════════════════════════════════════"
    print_title "  文件分类统计报告"
    echo "════════════════════════════════════════════"
    for cat in "${!classify_stats[@]}"; do
        printf "  %-12s : %d 个文件\n" "$cat" "${classify_stats[$cat]}"
    done
    echo "────────────────────────────────────────────"
    printf "  总计移动     : %d 个文件\n" "$total_moved"
    printf "  总计跳过     : %d 个文件\n" "$total_skipped"
    echo "════════════════════════════════════════════"
    log "INFO" "分类完成：移动 $total_moved 个文件，跳过 $total_skipped 个"
}

# 显示分类规则
show_rules() {
    echo
    print_title "文件分类规则："
    echo "────────────────────────────────────────────"
    for category in "${!FILE_TYPE_MAP[@]}"; do
        local dir
        case "$category" in
            "课件")   dir="$DIR_COURSEWARE" ;;
            "代码")   dir="$DIR_CODE" ;;
            "图片")   dir="$DIR_IMAGES" ;;
            "压缩包") dir="$DIR_ARCHIVES" ;;
            "视频")   dir="$DIR_VIDEOS" ;;
            "音乐")   dir="$DIR_MUSIC" ;;
        esac
        printf "  %-8s -> %s\n" "${category}" "$dir"
        printf "           后缀: %s\n" "${FILE_TYPE_MAP[$category]}"
    done
    printf "  %-8s -> %s\n" "其他" "$DIR_OTHERS"
    echo
    echo "  课件二级分类: 课程名 / 论文 / 未分类"
    echo "  代码二级分类: Web开发 / 算法练习 / 数据库 / Shell脚本 / Java项目 / Python项目 / 未分类"
    echo "────────────────────────────────────────────"
}

# 主函数
main() {
    local dry_run=false
    local show_rules_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n)
                dry_run=true
                shift ;;
            --rules|-r)
                show_rules_only=true
                shift ;;
            --dir|-d)
                TARGET_DIRS=("$2")
                shift 2 ;;
            *) shift ;;
        esac
    done

    ensure_dirs
    check_deps || return 1

    if [ "$show_rules_only" = true ]; then
        show_rules
        return
    fi

    show_banner
    print_title ">> 文件智能分类模块"
    echo
    show_rules

    if [ "$dry_run" = true ]; then
        print_warning "【预览模式】不会实际移动文件"
        echo
    fi

    for dir in "${TARGET_DIRS[@]}"; do
        run_classify "$dir" "$dry_run"
    done

    show_classify_stats

    if [ "$dry_run" = false ] && [ $total_moved -gt 0 ]; then
        notify_user "SFO 分类完成" "已整理 $total_moved 个文件"
    fi
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
