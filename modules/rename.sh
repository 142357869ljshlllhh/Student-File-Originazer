#!/bin/bash
# ============================================================
# 模块：文件命名规范化 (rename.sh)
# 功能：将 IMG_xxxx 格式的照片重命名为统一标准格式
# ============================================================

source "$(dirname "$0")/utils.sh"
TARGET_DIRS=("$SFO_ROOT")

renamed_count=0
skipped_count=0

# 批量重命名 IMG_ 格式文件
rename_img_files() {
    local target_dir="$1"
    local dry_run="${2:-false}"

    log "INFO" "开始重命名目录: $target_dir"

    if [ ! -d "$target_dir" ]; then
        log "WARN" "目录不存在，跳过: $target_dir"
        return
    fi

    while IFS= read -r -d '' file; do
        [ -d "$file" ] && continue

        local dir
        dir="$(dirname "$file")"
        local filename
        filename="$(basename "$file")"

        # 匹配 IMG_YYYYMMDD_HHMMSS.ext 格式
        if [[ "$filename" =~ ^IMG_([0-9]{4})([0-9]{2})([0-9]{2})_(.*)\.(.+)$ ]]; then
            local year="${BASH_REMATCH[1]}"
            local month="${BASH_REMATCH[2]}"
            local day="${BASH_REMATCH[3]}"
            local rest="${BASH_REMATCH[4]}"
            local ext="${BASH_REMATCH[5]}"

            local new_name="图片_${year}-${month}-${day}_${rest}.${ext,,}"
            local new_path="$dir/$new_name"

            if [ "$dry_run" = true ]; then
                print_info "[预览] $filename -> $new_name"
                ((renamed_count++))
                continue
            fi

            # 执行重命名
            if [ -f "$new_path" ]; then
                print_warning "目标已存在，跳过: $new_name"
                log "WARN" "重命名冲突: $file -> $new_path"
                ((skipped_count++))
            elif mv "$file" "$new_path" 2>/dev/null; then
                print_success "$filename -> $new_name"
                log "INFO" "重命名: $file -> $new_path"
                ((renamed_count++))
            else
                print_error "重命名失败: $filename"
                log "ERROR" "重命名失败: $file"
                ((skipped_count++))
            fi
        fi
    done < <(find "$target_dir" -type f -print0 2>/dev/null)
}

# 自定义重命名规则（按模式批量替换）
batch_rename() {
    local target_dir="$1"
    local pattern="$2"
    local replacement="$3"
    local dry_run="${4:-false}"

    if [ ! -d "$target_dir" ]; then
        print_error "目录不存在: $target_dir"
        return 1
    fi

    if [ -z "$pattern" ] || [ -z "$replacement" ]; then
        print_error "请提供查找模式和替换文本"
        echo "用法: $0 batch <目录> <查找模式> <替换文本> [--dry-run]"
        return 1
    fi

    local count=0
    while IFS= read -r -d '' file; do
        local dir
        dir="$(dirname "$file")"
        local filename
        filename="$(basename "$file")"
        local new_name="${filename//$pattern/$replacement}"

        if [ "$filename" != "$new_name" ]; then
            local new_path="$dir/$new_name"
            if [ "$dry_run" = true ]; then
                print_info "[预览] $filename -> $new_name"
            elif mv "$file" "$new_path" 2>/dev/null; then
                print_success "$filename -> $new_name"
                ((count++))
            else
                print_error "重命名失败: $filename"
            fi
        fi
    done < <(find "$target_dir" -maxdepth 1 -type f -print0 2>/dev/null)

    log "INFO" "批量重命名完成: $count 个文件"
}

# 去除文件名中的空格和特殊字符
sanitize_filenames() {
    local target_dir="$1"
    local dry_run="${2:-false}"

    if [ ! -d "$target_dir" ]; then
        print_error "目录不存在: $target_dir"
        return
    fi

    local count=0
    while IFS= read -r -d '' file; do
        local dir
        dir="$(dirname "$file")"
        local filename
        filename="$(basename "$file")"

        # 替换空格和中文符号为下划线
        local new_name
        new_name=$(echo "$filename" | sed -e 's/[[:space:]]/_/g' \
                                        -e 's/[（）【】《》「」『』〔〕]//g' \
                                        -e 's/[：；？！，。、]/_/g' \
                                        -e 's/__*/_/g')

        if [ "$filename" != "$new_name" ]; then
            local new_path="$dir/$new_name"
            if [ "$dry_run" = true ]; then
                print_info "[预览] $filename -> $new_name"
            elif mv "$file" "$new_path" 2>/dev/null; then
                print_success "$filename -> $new_name"
                ((count++))
            else
                print_error "处理失败: $filename"
            fi
        fi
    done < <(find "$target_dir" -maxdepth 1 -type f -print0 2>/dev/null)

    print_info "共清理 $count 个文件名"
}

# 显示统计
show_rename_stats() {
    echo
    echo "════════════════════════════════════════════"
    print_title "  文件重命名统计"
    echo "════════════════════════════════════════════"
    printf "  已重命名     : %d 个文件\n" "$renamed_count"
    printf "  已跳过       : %d 个文件\n" "$skipped_count"
    echo "════════════════════════════════════════════"
}

# 主函数
main() {
    local action="${1:-img}"
    local target_dir="${2:-}"
    local dry_run=false

    # 解析参数
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|-n) dry_run=true; shift ;;
            *) target_dir="$1"; shift ;;
        esac
    done

    ensure_dirs
    check_deps || return 1

    show_banner

    case "$action" in
        img)
            print_title ">> IMG_ 格式文件重命名模块"
            echo
            if [ -n "$target_dir" ]; then
                rename_img_files "$target_dir" "$dry_run"
            else
                for dir in "${TARGET_DIRS[@]}"; do
                    rename_img_files "$dir" "$dry_run"
                done
            fi
            show_rename_stats
            ;;
        batch)
            print_title ">> 批量文件重命名模块"
            echo
            batch_rename "$target_dir" "$2" "$3" "$dry_run"
            ;;
        sanitize)
            print_title ">> 文件名清理模块"
            echo
            if [ -n "$target_dir" ]; then
                sanitize_filenames "$target_dir" "$dry_run"
            else
                for dir in "${TARGET_DIRS[@]}"; do
                    sanitize_filenames "$dir" "$dry_run"
                done
            fi
            ;;
        *)
            echo "用法: $0 {img|batch|sanitize} [目录] [选项]"
            echo "  img      - 重命名 IMG_ 格式照片为标准格式（默认）"
            echo "  batch    - 批量替换文件名中的指定文本"
            echo "  sanitize - 清理文件名中的空格和特殊字符"
            echo "  --dry-run - 预览模式，不实际修改"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
