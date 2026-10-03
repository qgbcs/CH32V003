@echo off
REM ===================================================================
REM  CH32V003 单线调试 printf 监视器 (无需 UART 线)
REM  printf 经 WCH-LinkE + SDI 单线 (PD1/SWDIO) 传出, 监视器实时显示。
REM
REM  编码自适应守卫: 本文件为 GB18030 / 936。从 UTF-8 集成终端 (65001)
REM  启动时自动开新的 936 控制台窗口重跑自己; 双击则原地运行。
REM ===================================================================
chcp | find "65001" >nul && ( start "CH32V003 Printf Monitor" "%~f0" & exit /b 0 )
chcp 936 >nul
title CH32V003 printf Monitor (SWDIO)
cd /d "%~dp0"

set OCD_ROOT=%~dp0wch-tools\openocd-wch\openocd-wch-ch32v003-bootfix-0.11.0-ch32v003bootfix.3-windows-x86-wchdriver

echo [1/2] 关闭可能占用 LinkE 的旧调试进程 ...
taskkill /F /IM openocd.exe >nul 2>nul
timeout /t 1 /nobreak >nul

echo [2/2] 启动单线调试 printf 监视器 ...
echo        正在连接 WCH-LinkE, 请确保其已切到 WCH-LinkRV 模式
echo        接线: SWDIO-PD1  GND  3V3
echo.
"%OCD_ROOT%\bin\openocd.exe" -s "%OCD_ROOT%\scripts" -f "%~dp0ch32v003.cfg" -f "%~dp0monitor_printf.tcl"

echo.
echo !!! 监视器异常退出或没有输出, 请检查:
echo     1. LinkE 是否为 WCH-LinkRV 模式 (非 ARM/DAP 模式)
echo     2. led_scan 是否处于 normal 模式 (武装后需断电上电恢复)
echo     3. 接线 SWDIO-PD1 GND 3V3 是否牢靠
echo.
pause
