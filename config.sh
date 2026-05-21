#!/bin/bash
# ============================================================
# 大学生文件自动整理工具（SFO）- 配置文件
# ============================================================

# ---------- 目标目录 ----------
# 需要整理的目录列表，可按需添加多个目录
TARGET_DIRS=(
    "$HOME/SFO_TestFiles"
)

# ---------- 整理输出根目录 ----------
SFO_ROOT="$HOME/SFO_Organized"

# ---------- 分类输出目录 ----------
DIR_COURSEWARE="$SFO_ROOT/课件"
DIR_CODE="$SFO_ROOT/代码"
DIR_IMAGES="$SFO_ROOT/图片"
DIR_ARCHIVES="$SFO_ROOT/压缩包"
DIR_VIDEOS="$SFO_ROOT/视频"
DIR_MUSIC="$SFO_ROOT/音乐"
DIR_OTHERS="$SFO_ROOT/其他"

# ---------- 文件类型映射 ----------
declare -A FILE_TYPE_MAP
FILE_TYPE_MAP["课件"]="pdf ppt pptx doc docx xls xlsx txt md"
FILE_TYPE_MAP["代码"]="c cpp py java js html css sh go rs ts jsx tsx vue sql"
FILE_TYPE_MAP["图片"]="jpg jpeg png gif bmp svg ico webp"
FILE_TYPE_MAP["压缩包"]="zip rar 7z tar gz bz2 xz"
FILE_TYPE_MAP["视频"]="mp4 mkv avi mov flv wmv webm"
FILE_TYPE_MAP["音乐"]="mp3 wav flac aac ogg wma"

# ---------- 阈值设置 ----------
LARGE_FILE_SIZE_MB=100        # 大文件阈值（MB）
OLD_FILE_DAYS=30              # 旧文件阈值（天）
DUPLICATE_MIN_SIZE_KB=1       # 重复文件检测最小大小（KB）

# ---------- 备份设置 ----------
BACKUP_DIR="$SFO_ROOT/.sfo_backup"
BACKUP_KEEP_COUNT=5           # 最多保留最近 N 份备份

# ---------- 日志设置 ----------
LOG_DIR="$SFO_ROOT/logs"
LOG_FILE="$LOG_DIR/sfo_$(date +%Y%m%d).log"
LOG_MAX_SIZE_MB=10
LOG_KEEP_DAYS=30

# ---------- 排除规则 ----------
EXCLUDE_PATTERNS=(
    "*.tmp"
    "*.temp"
    "*.cache"
    ".*"
    "~*"
    "Thumbs.db"
    "desktop.ini"
)

# ---------- 颜色定义 ----------
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_BOLD='\033[1m'
COLOR_RESET='\033[0m'

# ---------- 图片重命名规则 ----------
# IMG_20230501_143022.jpg -> 图片_2023-05-01_143022.jpg
RENAME_PATTERN_IMG="IMG_([0-9]{4})([0-9]{2})([0-9]{2})_(.*)"
RENAME_REPLACE_IMG="图片_\1-\2-\3_\4"