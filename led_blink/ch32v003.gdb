# CH32V003 GDB 调试脚本 (RISC-V, WCH-LinkE + OpenOCD :3333)
set pagination off
set confirm off
set height unlimited
set output-radix 16

# 本机 xpack GCC 编译, 调试信息中的源码路径即为 C:/QGB/... 绝对路径, 无需映射
directory C:/QGB/CH32V003/led_blink C:/QGB/CH32V003/ch32fun/ch32fun

file main.elf

target extended-remote localhost:3333

# 复位并停在复位向量 (本 OpenOCD 含 ch32v003 bootfix, reset 不会跳丢)
monitor reset halt

break main
continue

# 源码单步界面
layout src
refresh

echo \n=== CH32V003 已停在 main, 常用命令: n 单步越过  s 单步进入  b main.c:21 设断点  c 继续  p/x *(int*)0x40011400 读寄存器 ===\n
