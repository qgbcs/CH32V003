#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# CH32V003 自动化构建脚本（仅编译，不烧录）
# 生成 main.elf / main.bin / main.hex / main.lst
# ============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUN_DIR="$ROOT_DIR/ch32fun"
PROJECT_NAME="main"

echo "=== 1. 检查并自动安装系统依赖 ==="
REQUIRED_PKGS="build-essential gcc-riscv64-unknown-elf git make libusb-1.0-0-dev libudev-dev pkg-config"
NEEDS_INSTALL=false

for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "检测到缺失依赖: $pkg"
        NEEDS_INSTALL=true
    fi
done

if [ "$NEEDS_INSTALL" = true ]; then
    echo "正在自动使用 apt 安装缺失的依赖包..."
    if [ "$(id -u)" -ne 0 ]; then
        sudo apt-get update
        sudo apt-get install -y $REQUIRED_PKGS
    else
        apt-get update
        apt-get install -y $REQUIRED_PKGS
    fi
    echo "依赖安装完成！"
else
    echo "所有基础 apt 依赖已安装。"
fi

echo ""
echo "=== 2. 检查并自动下载头文件与依赖库 ==="
if [ ! -d "$FUN_DIR" ]; then
    echo "未检测到 ch32fun 库，正在通过 Git 自动下载..."
    git clone https://github.com/cnlohr/ch32fun.git "$FUN_DIR"
else
    echo "ch32fun 库已存在。"
fi

echo ""
echo "=== 3. 准备 funconfig.h ==="
FUNCONFIG_PATH="$ROOT_DIR/funconfig.h"
if [ ! -f "$FUNCONFIG_PATH" ]; then
    echo "未找到 funconfig.h，正在从模板创建..."
    TEMPLATE_FUNCONFIG="$FUN_DIR/ch32fun/funconfig.h"
    if [ -f "$TEMPLATE_FUNCONFIG" ]; then
        cp "$TEMPLATE_FUNCONFIG" "$FUNCONFIG_PATH"
        echo "已从模板创建 funconfig.h。"
    else
        echo "警告：未找到模板，创建最小 funconfig.h。"
        cat > "$FUNCONFIG_PATH" << 'EOF'
#ifndef _FUNCONFIG_H
#define _FUNCONFIG_H
#endif
EOF
    fi
else
    echo "funconfig.h 已存在。"
fi

echo ""
echo "=== 4. 创建兼容头文件 ch32v003fun.h ==="
COMPAT_HEADER="$ROOT_DIR/ch32v003fun.h"
if [ ! -f "$COMPAT_HEADER" ]; then
    echo "创建兼容头文件 ch32v003fun.h -> ch32fun.h"
    cat > "$COMPAT_HEADER" << 'EOF'
#ifndef _CH32V003FUN_H
#define _CH32V003FUN_H
#include "ch32fun.h"
#endif
EOF
else
    echo "兼容头文件 ch32v003fun.h 已存在。"
fi

echo ""
echo "=== 5. 生成项目 Makefile ==="
MK_FILE_PATH=$(find "$FUN_DIR" -name "ch32fun.mk" -o -name "ch32v003fun.mk" | head -n 1)

if [ -z "$MK_FILE_PATH" ]; then
    echo "❌ 错误：找不到 ch32fun.mk，请删除 ch32fun 文件夹重试！"
    exit 1
fi

CH32FUN_CORE_DIR=$(dirname "$MK_FILE_PATH")
MK_FILE_NAME=$(basename "$MK_FILE_PATH")

# 变量必须先定义，再 include ch32fun.mk
# 不定义 all，避免与库中可能不存在的规则冲突
cat << EOF > "$ROOT_DIR/Makefile"
TARGET:=$PROJECT_NAME
CH32FUN:=$CH32FUN_CORE_DIR
CH32V003FUN:=$CH32FUN_CORE_DIR
TARGET_MCU:=CH32V003
EXTRA_CFLAGS += -I.

include \$(CH32FUN)/$MK_FILE_NAME

flash : cv_flash
clean : cv_clean
EOF
echo "自动生成了 Makefile，已指向核心库: $CH32FUN_CORE_DIR"

echo ""
echo "=== 6. 开始编译项目（仅编译，不烧录） ==="
cd "$ROOT_DIR"
make clean

# 直接指定具体文件作为目标，make 会自动按依赖链生成 .elf -> .bin / .hex
if make "$PROJECT_NAME.elf" "$PROJECT_NAME.bin" "$PROJECT_NAME.hex"; then
    echo ""
    echo "✅ 编译成功！"
    echo "输出文件:"
    ls -lh "$PROJECT_NAME.elf" "$PROJECT_NAME.bin" "$PROJECT_NAME.hex" 2>/dev/null || true
    echo "（已跳过烧录，如需烧录请手动执行: make flash）"
else
    echo "❌ 编译失败，请检查 main.c 或库配置。"
    exit 1
fi