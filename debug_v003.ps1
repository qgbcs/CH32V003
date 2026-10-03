# ===================================================================
# CH32V003 + WCH-LinkE 一键 OpenOCD + RISC-V GDB 单步调试
# 窗口1: OpenOCD GDB Server (端口 3333)
# 窗口2: riscv-none-elf-gdb TUI 源码单步界面
# ===================================================================
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OcdRoot    = Join-Path $ProjectDir 'wch-tools\openocd-wch\openocd-wch-ch32v003-bootfix-0.11.0-ch32v003bootfix.3-windows-x86-wchdriver'
$GdbExe     = Join-Path $ProjectDir 'wch-tools\xpack-riscv-none-elf-gcc-15.2.0-1\bin\riscv-none-elf-gdb.exe'
$GdbScript  = Join-Path $ProjectDir 'led_blink\ch32v003.gdb'
$GdbWorkDir = Join-Path $ProjectDir 'led_blink'

# 清掉可能残留的实例
Get-Process openocd,riscv-none-elf-gdb -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

# 窗口1: OpenOCD (-NoExit 保证出错时窗口不消失)
$ocdCmd = "`$Host.UI.RawUI.WindowTitle='OpenOCD CH32V003 :3333'; & '$OcdRoot\bin\openocd.exe' -s '$OcdRoot\scripts' -f '$ProjectDir\ch32v003.cfg'"
Start-Process -FilePath 'powershell.exe' -WorkingDirectory $ProjectDir -ArgumentList @(
    '-NoExit','-Command',$ocdCmd
)

Start-Sleep -Seconds 3

# 窗口2: RISC-V GDB TUI
$gdbCmd = "chcp 65001 > `$null; mode con: cols=132 lines=43; `$Host.UI.RawUI.WindowTitle='CH32V003 GDB main.elf'; & '$GdbExe' -q -tui -x '$GdbScript'"
Start-Process -FilePath 'powershell.exe' -WorkingDirectory $GdbWorkDir -ArgumentList @(
    '-NoExit','-Command',$gdbCmd
)
