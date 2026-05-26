#!/bin/bash
# ============================================================
# SFO 测试文件生成器
# 用法: bash generate_test_files.sh
# 生成 ~/SFO_TestFiles/ 包含混合类型的测试文件
#
# 工作流: classify 将文件移至 ~/SFO_Organized/
#         后续模块 scan ~/SFO_Organized/
# ============================================================

OUT_DIR="$HOME/SFO_TestFiles"

echo "========================================"
echo "  SFO 测试文件生成器"
echo "  输出: $OUT_DIR"
echo "========================================"
echo

if [ -d "$OUT_DIR" ]; then
    read -r -p "目录已存在，是否覆盖? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi
    rm -rf "$OUT_DIR"
fi

mkdir -p "$OUT_DIR"
cd "$OUT_DIR" || exit 1

# ============================================================
# 1. 课件类
# ============================================================
echo "[1/5] 课件类..."
echo "《数据结构》期末复习笔记" > "数据结构笔记.pdf"
echo "《操作系统》课程PPT内容" > "操作系统课件.ppt"
echo "实验报告内容"            > "计算机网络实验报告.docx"
echo "学习计划"                > "学习计划.txt"
echo "# 项目README"            > "README.md"
echo "成绩表格数据"            > "计组知识点.xlsx"

# ============================================================
# 2. 代码类
# ============================================================
echo "[2/5] 代码类..."
cat > "hello.c" << 'EOF'
#include <stdio.h>
int main() { printf("Hello, World!\n"); return 0; }
EOF
cat > "sort.py" << 'EOF'
def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n - i - 1):
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
    return arr
EOF
echo 'public class Main { public static void main(String[] a) {} }' > "Main.java"
echo 'const app = require("express")' > "app.js"
echo "body { margin: 0; font: sans-serif; }" > "style.css"
echo "<html><body><h1>Test</h1></body></html>" > "index.html"
echo '#!/bin/bash' > "test.sh"
echo "SELECT * FROM users;" > "query.sql"
echo "<template><div>Hello</div></template>" > "App.vue"
echo "const Comp: React.FC = () => <div/>" > "Component.tsx"

# ============================================================
# 3. 图片类
# ============================================================
echo "[3/5] 图片、压缩包、音视频..."
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' > "照片.jpg"
cp "照片.jpg" "截图.png"
cp "照片.jpg" "图标.gif"
cp "照片.jpg" "logo.svg"
cp "照片.jpg" "favicon.ico"

# 压缩包
echo "zip_content"  > "项目源码.zip"
echo "tar_content"  > "备份文件.tar.gz"
echo "rar_content"  > "资料.rar"

# 视频
echo "fake_mp4" > "课程录制.mp4"
echo "fake_mkv" > "教学视频.mkv"
echo "fake_avi" > "演示视频.avi"

# 音乐
echo "fake_mp3" > "英语听力.mp3"
echo "fake_wav" > "课堂录音.wav"
echo "fake_aac" > "播客节目.aac"

# 未知类型 → 归类"其他"
echo "binary_data" > "未知文件.xyz"
echo "config_data" > "settings.dat"

# ============================================================
# 4. 重复文件（3组）
# ============================================================
echo "[4/5] 重复文件、IMG_文件、大文件..."

echo "这是论文初稿的内容，包含实验数据和结论部分。" > "论文初稿.doc"
cp "论文初稿.doc" "论文初稿_副本.doc"
cp "论文初稿.doc" "论文初稿_备份.doc"

cat > "实验报告.pdf" << 'EOF'
实验名称: 操作系统进程调度
实验日期: 2024-05-20
实验人: 张三
实验结果: 验证了FCFS和RR调度算法
EOF
cp "实验报告.pdf" "实验报告_v2.pdf"
cp "实验报告.pdf" "实验报告_重命名.pdf"

echo '{"port":8080,"debug":true}' > "config.js"
cp "config.js" "config_backup.js"

# 唯一文件
echo "独一无二的内容 - 没有重复" > "唯一的笔记.txt"

# IMG_ 格式文件
echo "photo1" > "IMG_20230501_143022.jpg"
echo "photo2" > "IMG_20231225_180000.jpg"
echo "photo3" > "IMG_20240101_000001.png"
echo "photo4" > "IMG_20240315_120000.webp"
echo "normal"  > "普通照片.jpg"
echo "screenshot" > "Screenshot_20240501.png"

# 大文件 (占位)

echo "small" > "小文件.txt"

# ============================================================
# 5. 中文搜索测试
# ============================================================
echo "[5/5] 中文搜索测试文件..."
echo "高等数学期末考试试题" > "高等数学_期末试卷.pdf"
echo "高等数学课后答案"     > "高数作业答案.docx"
echo "python入门教程"       > "Python基础教程.pdf"
echo "python数据分析实战"   > "Python数据分析.md"
echo "Java程序设计实验报告"  > "Java实验报告.doc"
echo "C语言期末考试"        > "C语言复习资料.pdf"

echo
echo "========================================"
echo "  生成完成!"
echo "========================================"
echo "  目录: $OUT_DIR"
echo "  文件数: $(find "$OUT_DIR" -maxdepth 1 -type f | wc -l)"
echo "  总大小: $(du -sh "$OUT_DIR" 2>/dev/null | awk '{print $1}')"
echo
echo "下一步:"
echo "  ./sfo.sh --classify    # 分类到 ~/SFO_Organized/"
echo "  ./sfo.sh --auto-all    # 一键完整流程"
echo "  bash test_files/test_runner.sh all  # 自动化测试"
