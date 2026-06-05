#!/bin/bash
# ============================================================
# 大学生文件自动整理工具（SFO）- 配置文件
# ============================================================

# ---------- 项目根目录/演示目录 ----------
# 默认将测试数据与整理结果都放在项目目录内，便于在 Windows 资源管理器中直接展示
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="${SFO_DEMO_ROOT:-$CONFIG_DIR/demo_data}"

# ---------- 目标目录 ----------
# 需要整理的目录列表，可按需添加多个目录
TARGET_DIRS=(
    "$DEMO_ROOT/SFO_TestFiles"
)

# ---------- 整理输出根目录 ----------
SFO_ROOT="$DEMO_ROOT/SFO_Organized"

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

# ---------- 课件二级分类规则 ----------
COURSE_CATEGORY_ORDER=(
    "Linux系统与Shell编程"
    "操作系统"
    "数据结构"
    "算法设计与分析"
    "计算机网络"
    "数据库原理"
    "计算机组成原理"
    "软件工程"
    "编译原理"
    "Java程序设计"
    "Python程序设计"
    "C语言程序设计"
    "离散数学"
    "高等数学"
    "线性代数"
    "概率论与数理统计"
)

declare -A COURSE_KEYWORD_MAP
COURSE_KEYWORD_MAP["Linux系统与Shell编程"]="linux shell bash awk sed grep 脚本 命令行"
COURSE_KEYWORD_MAP["操作系统"]="操作系统 os 进程 线程 调度 死锁 内存管理 文件系统"
COURSE_KEYWORD_MAP["数据结构"]="数据结构 链表 栈 队列 树 图 排序 查找"
COURSE_KEYWORD_MAP["算法设计与分析"]="算法 algorithm leetcode acm oj 动态规划 贪心 分治 回溯 最短路径"
COURSE_KEYWORD_MAP["计算机网络"]="计算机网络 计网 网络 tcp ip udp http 路由 交换"
COURSE_KEYWORD_MAP["数据库原理"]="数据库 数据库原理 sql mysql oracle redis mongodb 事务 范式"
COURSE_KEYWORD_MAP["计算机组成原理"]="计算机组成原理 计组 组成原理 cpu 指令系统 存储器 流水线"
COURSE_KEYWORD_MAP["软件工程"]="软件工程 需求分析 uml 测试 设计模式 项目管理"
COURSE_KEYWORD_MAP["编译原理"]="编译原理 词法分析 语法分析 语义分析 编译器 自动机"
COURSE_KEYWORD_MAP["Java程序设计"]="java 面向对象 jvm spring maven servlet mybatis"
COURSE_KEYWORD_MAP["Python程序设计"]="python pandas numpy django flask scrapy 数据分析 爬虫"
COURSE_KEYWORD_MAP["C语言程序设计"]="c语言 c程序 指针 数组 结构体"
COURSE_KEYWORD_MAP["离散数学"]="离散数学 离散 集合论 图论 数理逻辑 布尔代数"
COURSE_KEYWORD_MAP["高等数学"]="高数 高等数学 微积分 导数 积分 极限 数学分析"
COURSE_KEYWORD_MAP["线性代数"]="线代 线性代数 矩阵 向量 行列式 特征值"
COURSE_KEYWORD_MAP["概率论与数理统计"]="概率论 概率 数理统计 概统 随机变量 分布 期望"

PAPER_KEYWORDS=(
    "论文"
    "paper"
    "survey"
    "manuscript"
    "毕业论文"
    "毕业设计"
    "毕设"
    "开题"
    "综述"
)

# ---------- 代码二级分类规则 ----------
CODE_DIRECTION_ORDER=(
    "Web开发"
    "算法练习"
    "数据库"
    "Shell脚本"
    "Java项目"
    "Python项目"
)

declare -A CODE_DIRECTION_KEYWORD_MAP
CODE_DIRECTION_KEYWORD_MAP["Web开发"]="web html css javascript js typescript ts vue react node express 前端 后端 页面"
CODE_DIRECTION_KEYWORD_MAP["算法练习"]="algorithm algo sort tree graph stack queue linkedlist binarytree leetcode acm oj 数据结构 算法 排序 链表 树 图"
CODE_DIRECTION_KEYWORD_MAP["数据库"]="database sql mysql oracle redis mongodb 数据库 事务 范式"
CODE_DIRECTION_KEYWORD_MAP["Shell脚本"]="shell bash awk sed grep linux 脚本 运维"
CODE_DIRECTION_KEYWORD_MAP["Java项目"]="java spring maven servlet mybatis junit hibernate"
CODE_DIRECTION_KEYWORD_MAP["Python项目"]="python pandas numpy django flask scrapy pytorch tensorflow 数据分析 爬虫 机器学习 深度学习"

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
