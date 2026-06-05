#!/bin/bash
# ============================================================
# 大学生文件自动整理工具 - 工具函数库
# ============================================================

# 加载配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"

# 确保目录存在
ensure_dirs() {
    local dirs=("$SFO_ROOT" "$DIR_COURSEWARE" "$DIR_CODE" "$DIR_IMAGES" "$DIR_ARCHIVES" "$DIR_VIDEOS" "$DIR_MUSIC" "$DIR_OTHERS" "$LOG_DIR" "$BACKUP_DIR")
    for d in "${dirs[@]}"; do
        mkdir -p "$d"
    done
}

# 日志记录
log() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    ensure_dirs
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 彩色输出
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${COLOR_RESET}"
}

print_success() { print_color "$COLOR_GREEN" "✓ $1"; }
print_error()   { print_color "$COLOR_RED"   "✗ $1"; }
print_warning() { print_color "$COLOR_YELLOW" "⚠ $1"; }
print_info()    { print_color "$COLOR_CYAN"   "ℹ $1"; }
print_title()   { print_color "$COLOR_BOLD"  "$1"; }

# 用户确认
confirm() {
    local prompt="${1:-是否继续? [y/N]}"
    read -r -p "$prompt " answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# 获取文件扩展名（小写）
get_ext() {
    local filename="$1"
    local ext="${filename##*.}"
    echo "${ext,,}"  # 转为小写
}

# 获取一级分类名称
get_primary_category() {
    local ext="$1"
    for category in "${!FILE_TYPE_MAP[@]}"; do
        local exts="${FILE_TYPE_MAP[$category]}"
        if [[ " $exts " == *" $ext "* ]]; then
            echo "$category"
            return
        fi
    done
    echo "其他"
}

# 获取一级分类目录
get_category_dir() {
    local ext="$1"
    local category
    category="$(get_primary_category "$ext")"

    case "$category" in
        "课件")   echo "$DIR_COURSEWARE" ;;
        "代码")   echo "$DIR_CODE" ;;
        "图片")   echo "$DIR_IMAGES" ;;
        "压缩包") echo "$DIR_ARCHIVES" ;;
        "视频")   echo "$DIR_VIDEOS" ;;
        "音乐")   echo "$DIR_MUSIC" ;;
        *)        echo "$DIR_OTHERS" ;;
    esac
}

contains_keyword() {
    local text="${1,,}"
    shift

    for keyword in "$@"; do
        [ -z "$keyword" ] && continue
        if [[ "$text" == *"${keyword,,}"* ]]; then
            return 0
        fi
    done
    return 1
}

get_course_subcategory() {
    local filename="$1"
    local name_only="${filename%.*}"
    local normalized="${name_only,,}"

    if contains_keyword "$normalized" "${PAPER_KEYWORDS[@]}"; then
        echo "论文"
        return
    fi

    for course in "${COURSE_CATEGORY_ORDER[@]}"; do
        local keywords="${COURSE_KEYWORD_MAP[$course]}"
        read -r -a keyword_list <<< "$keywords"
        if contains_keyword "$normalized" "${keyword_list[@]}"; then
            echo "$course"
            return
        fi
    done

    echo "未分类"
}

get_code_fallback_subcategory() {
    local ext="$1"

    case "$ext" in
        html|css|js|ts|jsx|tsx|vue) echo "Web开发" ;;
        sql)                        echo "数据库" ;;
        sh)                         echo "Shell脚本" ;;
        java)                       echo "Java项目" ;;
        py)                         echo "Python项目" ;;
        c|cpp|go|rs)                echo "算法练习" ;;
        *)                          echo "未分类" ;;
    esac
}

get_code_subcategory() {
    local file_path="$1"
    local filename="$2"
    local ext="$3"
    local parent_dir
    parent_dir="$(basename "$(dirname "$file_path")")"
    local normalized="${filename,,} ${parent_dir,,}"

    for direction in "${CODE_DIRECTION_ORDER[@]}"; do
        local keywords="${CODE_DIRECTION_KEYWORD_MAP[$direction]}"
        read -r -a keyword_list <<< "$keywords"
        if contains_keyword "$normalized" "${keyword_list[@]}"; then
            echo "$direction"
            return
        fi
    done

    get_code_fallback_subcategory "$ext"
}

get_classify_target_dir() {
    local file_path="$1"
    local filename
    filename="$(basename "$file_path")"
    local ext
    ext="$(get_ext "$filename")"
    local base_dir
    base_dir="$(get_category_dir "$ext")"
    local category
    category="$(get_primary_category "$ext")"

    case "$category" in
        "课件")
            echo "$base_dir/$(get_course_subcategory "$filename")"
            ;;
        "代码")
            echo "$base_dir/$(get_code_subcategory "$file_path" "$filename" "$ext")"
            ;;
        *)
            echo "$base_dir"
            ;;
    esac
}

# 人类可读的文件大小
human_size() {
    local size="$1"
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$((size / 1024))KB"
    elif [ "$size" -lt 1073741824 ]; then
        echo "$((size / 1048576))MB"
    else
        echo "$((size / 1073741824))GB"
    fi
}

# 检查是否为排除文件
is_excluded() {
    local filename="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# 检查依赖命令
check_deps() {
    local missing=()
    local deps=("find" "mv" "cp" "rm" "mkdir" "md5sum" "stat" "grep" "sed" "awk" "date")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "缺少依赖命令: ${missing[*]}"
        return 1
    fi
    return 0
}

# 检查扩展依赖
check_ext_deps() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        print_warning "未安装 $cmd，相关功能不可用"
        return 1
    fi
    return 0
}

# 获取文件最后访问时间（天数）
get_file_age_days() {
    local file="$1"
    local now
    local file_time
    now=$(date +%s)
    file_time=$(stat -c %X "$file" 2>/dev/null || stat -f %a "$file" 2>/dev/null || echo "$now")
    echo $(( (now - file_time) / 86400 ))
}

# 获取文件大小（字节）
get_file_size() {
    local file="$1"
    stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo 0
}

# 显示进度条
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    if [ "$total" -eq 0 ]; then return; fi
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %3d%%" "$percent"
}

# 显示横幅
show_banner() {
    echo
    print_color "$COLOR_CYAN" "╔══════════════════════════════════════════════════════════╗"
    print_color "$COLOR_CYAN" "║       大学生文件自动整理工具 (SFO - Student File Organizer)     ║"
    print_color "$COLOR_CYAN" "╚══════════════════════════════════════════════════════════╝"
    echo
}

# 安全移动文件（处理重名）
safe_move() {
    local src="$1"
    local dst_dir="$2"
    mkdir -p "$dst_dir"
    local filename
    filename="$(basename "$src")"
    local dst="$dst_dir/$filename"

    # 如果目标已存在，添加序号
    if [ -f "$dst" ]; then
        local base="${filename%.*}"
        local ext="${filename##*.}"
        local counter=1
        while [ -f "$dst_dir/${base}_${counter}.${ext}" ]; do
            ((counter++))
        done
        dst="$dst_dir/${base}_${counter}.${ext}"
    fi

    mv "$src" "$dst" 2>/dev/null && echo "$dst" || return 1
}

# 发送桌面通知（跨平台）
notify_user() {
    local title="$1"
    local message="$2"
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message"
    elif command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\""
    fi
}
