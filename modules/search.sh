#!/bin/bash
# ============================================================
# 模块：全文件检索 (search.sh)
# 功能：按文件名、类型、大小、时间等条件搜索文件
# ============================================================

source "$(dirname "$0")/utils.sh"

# 构建文件索引数据库
build_index() {
    local index_file="$SFO_ROOT/.sfo_index.txt"

    print_info "正在构建文件索引..."
    log "INFO" "开始构建文件索引"

    {
        echo "# SFO 文件索引 - 生成于 $(date '+%Y-%m-%d %H:%M:%S')"
        for dir in "${TARGET_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                find "$dir" -type f \
                    -not -path "$SFO_ROOT/*" \
                    -printf '%p|%f|%s|%TFT%TR|%AF%AR\n' 2>/dev/null
            fi
        done
        # 同时索引 SFO 整理目录
        if [ -d "$SFO_ROOT" ]; then
            find "$SFO_ROOT" -type f -printf '%p|%f|%s|%TFT%TR|%AF%AR\n' 2>/dev/null
        fi
    } > "$index_file"

    local count
    count=$(wc -l < "$index_file" 2>/dev/null)
    print_success "索引构建完成: $((count - 1)) 个文件"
    log "INFO" "文件索引构建完成: $((count - 1)) 个文件"
}

# 按文件名搜索
search_by_name() {
    local keyword="$1"
    local exact_match="${2:-false}"

    if [ -z "$keyword" ]; then
        read -r -p "请输入搜索关键词: " keyword
    fi

    [ -z "$keyword" ] && { print_error "搜索关键词不能为空"; return 1; }

    print_info "搜索文件名: $keyword"
    echo
    echo "──────────────────────────────────────────────────────────────"

    local count=0
    for dir in "${TARGET_DIRS[@]}"; do
        [ -d "$dir" ] || continue

        if [ "$exact_match" = true ]; then
            find "$dir" -type f -name "$keyword" -not -path "$SFO_ROOT/*" \
                -printf '  %s|%p|%TF\n' 2>/dev/null | \
                while IFS='|' read -r size path mtime; do
                    printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
                done
        else
            find "$dir" -type f -iname "*${keyword}*" -not -path "$SFO_ROOT/*" \
                -printf '  %s|%p|%TF\n' 2>/dev/null | \
                while IFS='|' read -r size path mtime; do
                    printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
                done
        fi
    done

    # 同时搜索 SFO 目录
    if [ -d "$SFO_ROOT" ]; then
        if [ "$exact_match" = true ]; then
            find "$SFO_ROOT" -type f -name "$keyword" -printf '  %s|%p|%TF\n' 2>/dev/null | \
                while IFS='|' read -r size path mtime; do
                    printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
                done
        else
            find "$SFO_ROOT" -type f -iname "*${keyword}*" -printf '  %s|%p|%TF\n' 2>/dev/null | \
                while IFS='|' read -r size path mtime; do
                    printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
                done
        fi
    fi

    count=$(find "${TARGET_DIRS[@]}" "$SFO_ROOT" -type f -iname "*${keyword}*" 2>/dev/null | wc -l)
    echo "──────────────────────────────────────────────────────────────"
    print_info "共找到 $count 个匹配文件"
}

# 按文件类型搜索
search_by_type() {
    local ext="$1"

    if [ -z "$ext" ]; then
        read -r -p "请输入文件后缀 (如 pdf, jpg): " ext
    fi

    [ -z "$ext" ] && { print_error "后缀不能为空"; return 1; }

    # 去掉可能的前导点
    ext="${ext#.}"
    ext="${ext,,}"

    print_info "搜索 .$ext 文件"
    echo
    echo "──────────────────────────────────────────────────────────────"

    for dir in "${TARGET_DIRS[@]}"; do
        [ -d "$dir" ] || continue

        find "$dir" -type f -iname "*.${ext}" -not -path "$SFO_ROOT/*" \
            -printf '  %s|%p|%TF\n' 2>/dev/null | \
            while IFS='|' read -r size path mtime; do
                printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
            done
    done

    if [ -d "$SFO_ROOT" ]; then
        find "$SFO_ROOT" -type f -iname "*.${ext}" -printf '  %s|%p|%TF\n' 2>/dev/null | \
            while IFS='|' read -r size path mtime; do
                printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
            done
    fi

    local count
    count=$(find "${TARGET_DIRS[@]}" "$SFO_ROOT" -type f -iname "*.${ext}" 2>/dev/null | wc -l)
    echo "──────────────────────────────────────────────────────────────"
    print_info "共找到 $count 个 .$ext 文件"
}

# 按文件大小搜索
search_by_size() {
    local min_size="${1:-1}"  # 默认 >1MB

    print_info "搜索大于 ${min_size}MB 的文件"
    echo
    echo "──────────────────────────────────────────────────────────────"

    local min_bytes=$((min_size * 1024 * 1024))

    for dir in "${TARGET_DIRS[@]}"; do
        [ -d "$dir" ] || continue

        find "$dir" -type f -size "+${min_size}M" -not -path "$SFO_ROOT/*" \
            -printf '  %s|%p|%TF\n' 2>/dev/null | \
            sort -t'|' -k1 -rn | \
            while IFS='|' read -r size path mtime; do
                printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
            done
    done

    local count
    count=$(find "${TARGET_DIRS[@]}" -type f -size "+${min_size}M" -not -path "$SFO_ROOT/*" 2>/dev/null | wc -l)
    echo "──────────────────────────────────────────────────────────────"
    print_info "共找到 $count 个大文件"
}

# 按时间搜索（最近修改）
search_by_time() {
    local days="${1:-7}"

    print_info "搜索最近 ${days} 天内修改的文件"
    echo
    echo "──────────────────────────────────────────────────────────────"

    for dir in "${TARGET_DIRS[@]}"; do
        [ -d "$dir" ] || continue

        find "$dir" -type f -mtime "-${days}" -not -path "$SFO_ROOT/*" \
            -printf '  %TFT%TR|%s|%p\n' 2>/dev/null | \
            sort -r | head -50 | \
            while IFS='|' read -r mtime size path; do
                printf "  %-20s %-10s %s\n" "$mtime" "$(human_size $size)" "$path"
            done
    done

    local count
    count=$(find "${TARGET_DIRS[@]}" -type f -mtime "-${days}" -not -path "$SFO_ROOT/*" 2>/dev/null | wc -l)
    echo "──────────────────────────────────────────────────────────────"
    print_info "共找到 $count 个最近修改的文件"
}

# 高级搜索（多条件组合）
advanced_search() {
    echo
    print_title "高级搜索"
    echo "支持多条件组合搜索"
    echo

    read -r -p "文件名关键词 (回车跳过): " name_filter
    read -r -p "文件后缀 (回车跳过): " ext_filter
    read -r -p "最小大小/MB (回车跳过): " size_filter
    read -r -p "目标目录 (回车=全部): " dir_filter

    echo
    print_info "搜索中..."

    local search_dirs=()
    if [ -n "$dir_filter" ] && [ -d "$dir_filter" ]; then
        search_dirs=("$dir_filter")
    else
        search_dirs=("${TARGET_DIRS[@]}")
        [ -d "$SFO_ROOT" ] && search_dirs+=("$SFO_ROOT")
    fi

    # 构建 find 条件
    local find_args=(-type f)

    if [ -n "$name_filter" ]; then
        find_args+=(-iname "*${name_filter}*")
    fi
    if [ -n "$ext_filter" ]; then
        ext_filter="${ext_filter#.}"
        find_args+=(-iname "*.${ext_filter}")
    fi
    if [ -n "$size_filter" ] && [[ "$size_filter" =~ ^[0-9]+$ ]]; then
        find_args+=(-size "+${size_filter}M")
    fi

    echo "──────────────────────────────────────────────────────────────"
    local total=0
    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] || continue
        find_args+=(-not -path "$SFO_ROOT/.sfo_*")

        find "$dir" "${find_args[@]}" \
            -printf '  %s|%TF %TR|%p\n' 2>/dev/null | \
            while IFS='|' read -r size mtime path; do
                printf "  %-10s  %s  %s\n" "$(human_size $size)" "$mtime" "$path"
                ((total++))
            done
    done
    echo "──────────────────────────────────────────────────────────────"
    print_info "搜索完成"
}

# 主函数
main() {
    local action="${1:-name}"
    shift

    ensure_dirs
    check_deps || return 1

    show_banner

    case "$action" in
        name)
            print_title ">> 按文件名搜索"
            echo
            search_by_name "$1"
            ;;
        type|ext)
            print_title ">> 按文件类型搜索"
            echo
            search_by_type "$1"
            ;;
        size)
            print_title ">> 按文件大小搜索"
            echo
            search_by_size "$1"
            ;;
        time|recent)
            print_title ">> 按修改时间搜索"
            echo
            search_by_time "$1"
            ;;
        advanced)
            advanced_search
            ;;
        index)
            build_index
            ;;
        *)
            echo "用法: $0 {name|type|size|time|advanced|index} [参数]"
            echo "  name     - 按文件名关键词搜索"
            echo "  type     - 按文件后缀搜索"
            echo "  size     - 按文件大小搜索 (>N MB)"
            echo "  time     - 按修改时间搜索 (最近N天)"
            echo "  advanced - 高级组合搜索"
            echo "  index    - 重建文件索引"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
