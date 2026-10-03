@echo off
REM ===================================================================
REM  CH32V003 红灯固件 (PD1=SWDIO) - 编译 + 烧录 + 询问是否占用 DIO
REM
REM  编码自适应守卫 (见下一行):
REM  本文件是 GB18030, 依赖 936 代码页。若从 UTF-8 宿主 (如 TRAE / VS Code
REM  集成终端, 初始页 65001) 启动, 中文必显示 ?。守卫检测到 65001 后,
REM  自动开一个新的 936 控制台窗口重跑自己, 当前窗口退出。
REM  资源管理器双击时初始页就是 936, 守卫不动作, 原地运行。
REM ===================================================================
chcp | find "65001" >nul && ( start "CH32V003 Flasher" "%~f0" & exit /b 0 )
chcp 936 >nul
title CH32V003 LED Firmware Flasher
cd /d "%~dp0"

set OCD_ROOT=%~dp0wch-tools\openocd-wch\openocd-wch-ch32v003-bootfix-0.11.0-ch32v003bootfix.3-windows-x86-wchdriver

echo.
echo [0/3] 关闭可能占用 LinkE 的旧调试进程 ...
taskkill /F /IM openocd.exe           >nul 2>nul
taskkill /F /IM riscv-none-elf-gdb.exe >nul 2>nul

echo [1/3] 编译红灯固件 ...
call "%~dp0led_scan\build_scan.bat"
if errorlevel 1 goto :err

echo.
echo [2/3] OpenOCD 烧录 led_scan.bin (边擦边写 + 校验 + 复位运行) ...
"%OCD_ROOT%\bin\openocd.exe" -s "%OCD_ROOT%\scripts" -f "%~dp0ch32v003.cfg" -f "%~dp0flash_wch.tcl"
if errorlevel 1 goto :err

echo.
echo [3/3] 烧录完成, 固件已运行: 当前 DIO 空闲, SDI 调试口保持开启。
echo.
set /p OCCUPY=是否现在占用 DIO 点亮红灯? Y=占用 N=保持调试口(断电自动恢复):
if /I "%OCCUPY%"=="Y" goto :arm
echo.
echo 已保持调试口模式。之后想点红灯, 重新运行本脚本并选 Y 即可。
echo 查看单线 printf 输出: 双击 view_scan_printf.bat
pause
exit /b 0

:arm
echo.
echo 正在写入 SRAM 武装标志 ...
"%OCD_ROOT%\bin\openocd.exe" -s "%OCD_ROOT%\scripts" -f "%~dp0ch32v003.cfg" -f "%~dp0arm_led_mode.tcl"
if errorlevel 1 goto :armfail
echo.
echo ============================================================================
echo  完成: 固件约 1 秒内关闭 SDI, PD1 红灯以 0.5 秒间隔闪烁。
echo  之后 DIO 连不上属正常现象 ---- 给板子重新断电上电即恢复调试口。
echo ============================================================================
pause
exit /b 0

:armfail
echo.
echo !!! 武装失败 (但固件已正常运行, SDI 仍开启), 可重新运行本脚本再试。
pause
exit /b 1

:err
echo.
echo !!! 失败: 请确认 LinkE 已切到 WCH-LinkRV 模式, 接线 SWDIO-PD1 GND 3V3
pause
exit /b 1