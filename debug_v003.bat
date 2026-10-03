@echo off
REM CH32V003 一键调试启动器 (OpenOCD + RISC-V GDB), 双击即可
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0debug_v003.ps1"
