#!/bin/bash
# ============================================================
# 大学生文件自动整理工具（SFO）
# 主入口脚本
# 版本: 1.1
# ============================================================

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"

# 加载配置和公共函数
source "$SCRIPT_DIR/config.sh"
source "$MODULE_DIR/utils.sh"

# 初始化环境
init_environment() {
    ensure_dirs
    check_deps || {
        print_error "缺少必要依赖，请先安装后再运行。"
        return 1
    }
}

# 判断模块是否存在
module_exists() {
    local module_name="$1"
    [ -f "$MODULE_DIR/$module_name" ]
}

# 暂停并返回主菜单
pause_return() {
    echo
    read -r -p "按回车键返回主菜单..." _
}

# 显示主菜单
show_menu() {
    clear
    show_banner
    print_title "主菜单"
    echo
    printf "  目标目录：%s\n" "${TARGET_DIRS[*]}"
    printf "  整理输出：%s\n" "$SFO_ROOT"
    echo
    echo "  [核心功能]"
    printf "  ${COLOR_CYAN}%2s${COLOR_RESET}. 文件智能分类    - 按文件后缀自动归档\n" "1"
    printf "  ${COLOR_CYAN}%2s${COLOR_RESET}. 重复文件检测    - 基于 MD5 检测重复文件\n" "2"
    printf "  ${COLOR_CYAN}%2s${COLOR_RESET}. 文件命名规范    - 统一 IMG_ 类文件命名\n" "3"
    echo
    echo "  [扩展功能]"
    printf "  ${COLOR_GREEN}%2s${COLOR_RESET}. 空间使用统计    - 查看目录和分类占用情况\n" "4"
    printf "  ${COLOR_GREEN}%2s${COLOR_RESET}. 安全备份恢复    - 创建备份并支持恢复\n" "5"
    printf "  ${COLOR_GREEN}%2s${COLOR_RESET}. 全文文件搜索    - 按名称快速检索文件\n" "6"
    echo
    echo "  [系统管理]"
    printf "  ${COLOR_YELLOW}%2s${COLOR_RESET}. 查看运行日志    - 浏览历史执行记录\n" "7"
    printf "  ${COLOR_YELLOW}%2s${COLOR_RESET}. 系统依赖检查    - 检查运行环境\n" "8"
    printf "  ${COLOR_YELLOW}%2s${COLOR_RESET}. 一键全部执行    - 分类 + 去重 + 命名规范\n" "9"
    echo
    printf "  ${COLOR_RED}%2s${COLOR_RESET}. 退出程序\n" "0"
    echo
    printf "请选择功能 [0-9]："
}

# 查看日志
show_logs() {
    show_banner
    print_title ">> 运行日志"
    echo

    local log_files=()
    if [ -d "$LOG_DIR" ]; then
        while IFS= read -r -d '' file; do
            log_files+=("$file")
        done < <(find "$LOG_DIR" -name "sfo_*.log" -print0 2>/dev/null | sort -z)
    fi

    if [ ${#log_files[@]} -eq 0 ]; then
        print_warning "暂无日志文件。"
        return
    fi

    echo "日志文件列表："
    echo "------------------------------------------------------------"
    for i in "${!log_files[@]}"; do
        local file="${log_files[$i]}"
        local base size
        base="$(basename "$file")"
        size=$(stat -c %s "$file" 2>/dev/null || echo 0)
        printf "  %2d. %-30s %10s\n" "$((i + 1))" "$base" "$(human_size "$size")"
    done
    echo "------------------------------------------------------------"

    read -r -p "请选择要查看的日志 [1-${#log_files[@]}]，直接回车返回： " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#log_files[@]} ]; then
        local log_file="${log_files[$((choice - 1))]}"
        echo
        print_info "正在查看：$(basename "$log_file")"
        echo "------------------------------------------------------------"
        tail -100 "$log_file"
        echo "------------------------------------------------------------"
        print_info "以上为最后 100 行内容。"
    fi
}

# 一键执行
auto_all() {
    show_banner
    print_title ">> 一键全部执行"
    print_warning "将依次执行：文件分类 -> 重复检测 -> 文件命名规范"
    echo

    if ! confirm "确认继续？ [y/N]"; then
        print_info "已取消。"
        return
    fi

    echo
    print_info "[1/3] 正在执行文件智能分类..."
    bash "$MODULE_DIR/classify.sh"
    sleep 1

    echo
    print_info "[2/3] 正在执行重复文件检测..."
    bash "$MODULE_DIR/duplicate.sh" scan "$SFO_ROOT"
    sleep 1

    echo
    print_info "[3/3] 正在执行文件命名规范..."
    bash "$MODULE_DIR/rename.sh" img "$SFO_ROOT"

    echo
    print_success "一键执行完成。"
    log "INFO" "一键全部执行完成"
}

# 依赖检查
run_dependency_check() {
    show_banner
    print_title ">> 系统依赖检查"
    echo

    echo "[基础工具]"
    local basic_deps=("find" "mv" "cp" "rm" "mkdir" "touch" "md5sum" "stat" "grep" "sed" "awk" "date" "sort" "head" "tail")
    for cmd in "${basic_deps[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "  ${COLOR_GREEN}已安装${COLOR_RESET} %-12s\n" "$cmd"
        else
            printf "  ${COLOR_RED}缺失${COLOR_RESET}   %-12s\n" "$cmd"
        fi
    done

    echo
    echo "[扩展工具]"
    local ext_deps=("notify-send:libnotify-bin" "tar:tar" "df:coreutils" "du:coreutils")
    for item in "${ext_deps[@]}"; do
        local cmd="${item%%:*}"
        local pkg="${item##*:}"
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "  ${COLOR_GREEN}已安装${COLOR_RESET} %-16s\n" "$cmd"
        else
            printf "  ${COLOR_YELLOW}建议安装${COLOR_RESET} %-16s (apt install %s)\n" "$cmd" "$pkg"
        fi
    done

    echo
    echo "[目标目录]"
    for dir in "${TARGET_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            printf "  ${COLOR_GREEN}存在${COLOR_RESET} %s\n" "$dir"
        else
            printf "  ${COLOR_YELLOW}缺失${COLOR_RESET} %s\n" "$dir"
        fi
    done

    echo
    echo "[SFO 输出目录]"
    if [ -d "$SFO_ROOT" ]; then
        local sfo_size
        sfo_size=$(du -sh "$SFO_ROOT" 2>/dev/null | awk '{print $1}')
        printf "  ${COLOR_GREEN}存在${COLOR_RESET} %s (%s)\n" "$SFO_ROOT" "$sfo_size"
    else
        printf "  ${COLOR_CYAN}未创建${COLOR_RESET} %s\n" "$SFO_ROOT"
    fi

    echo
    print_info "依赖检查完成。"
    log "INFO" "依赖检查完成"
}

# 帮助信息
show_help() {
    cat <<'EOF'
大学生文件自动整理工具（SFO）

用法：
  ./sfo.sh [选项]

选项：
  --menu, -m          启动交互菜单
  --classify, -c      执行文件智能分类
  --duplicate, -d     执行重复文件检测
  --rename, -r        执行文件命名规范
  --stats             显示空间使用统计
  --backup            创建安全备份
  --search <关键词>   按名称搜索文件
  --auto-all          一键执行分类、去重、命名规范
  --check             执行依赖检查
  --help, -h          显示帮助信息
EOF
}

# 命令行模式处理
handle_cli() {
    case "$1" in
        --help|-h)
            show_help
            ;;
        --menu|-m)
            return 1
            ;;
        --classify|-c)
            bash "$MODULE_DIR/classify.sh"
            ;;
        --duplicate|-d)
            bash "$MODULE_DIR/duplicate.sh" scan
            ;;
        --rename|-r)
            bash "$MODULE_DIR/rename.sh" img
            ;;
        --stats)
            bash "$MODULE_DIR/stats.sh" full
            ;;
        --backup)
            bash "$MODULE_DIR/backup.sh" backup
            ;;
        --search)
            bash "$MODULE_DIR/search.sh" name "$2"
            ;;
        --auto-all)
            ensure_dirs
            check_deps >/dev/null 2>&1 || exit 1
            log "INFO" "自动执行开始"
            bash "$MODULE_DIR/classify.sh" >/dev/null 2>&1
            bash "$MODULE_DIR/duplicate.sh" scan >/dev/null 2>&1
            bash "$MODULE_DIR/rename.sh" img "$SFO_ROOT" >/dev/null 2>&1
            log "INFO" "自动执行完成"
            ;;
        --check)
            run_dependency_check
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

# 主函数
main() {
    init_environment

    if [ $# -gt 0 ]; then
        if handle_cli "$@"; then
            exit 0
        fi
    fi

    while true; do
        show_menu
        read -r choice

        case "$choice" in
            1)
                bash "$MODULE_DIR/classify.sh"
                ;;
            2)
                bash "$MODULE_DIR/duplicate.sh" scan
                ;;
            3)
                bash "$MODULE_DIR/rename.sh" img
                ;;
            4)
                bash "$MODULE_DIR/stats.sh" full
                ;;
            5)
                bash "$MODULE_DIR/backup.sh" backup
                ;;
            6)
                read -r -p "请输入搜索关键词： " keyword
                bash "$MODULE_DIR/search.sh" name "$keyword"
                ;;
            7)
                show_logs
                ;;
            8)
                run_dependency_check
                ;;
            9)
                auto_all
                ;;
            0)
                echo
                print_success "感谢使用，程序已退出。"
                echo
                exit 0
                ;;
            *)
                print_error "无效选择，请输入 0-9。"
                sleep 1
                ;;
        esac

        if [[ "$choice" =~ ^[1-9]$ ]]; then
            pause_return
        fi
    done
}

main "$@"