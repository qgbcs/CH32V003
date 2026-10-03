@echo off
REM ===================================================================
REM Build led_scan locally with xpack riscv-none-elf-gcc (no WSL/make)
REM ===================================================================
setlocal
cd /d "%~dp0"

set GCC_BIN=..\wch-tools\xpack-riscv-none-elf-gcc-15.2.0-1\bin
set FUN=..\ch32fun\ch32fun

echo [1/3] Generating linker script generated_ch32v003.ld ...
"%GCC_BIN%\riscv-none-elf-gcc.exe" -E -P -x c -DTARGET_MCU=CH32V003 -DMCU_PACKAGE=1 -DTARGET_MCU_LD=0 "%FUN%\ch32fun.ld" -o generated_ch32v003.ld
if errorlevel 1 goto :err

echo [2/3] Compiling and linking led_scan.elf ...
"%GCC_BIN%\riscv-none-elf-gcc.exe" -o led_scan.elf "%FUN%\ch32fun.c" led_scan.c -g -Os -ffunction-sections -fdata-sections -msmall-data-limit=8 -fno-tree-loop-distribute-patterns -fmessage-length=0 -march=rv32ec -mabi=ilp32e -DCH32V003 -static-libgcc -nostdlib -I. -I"%FUN%" -I..\ch32fun\extralibs -T generated_ch32v003.ld -Wl,--gc-sections -L..\ch32fun\misc -lgcc -Wl,-Map=led_scan.map -Wl,--print-memory-usage
if errorlevel 1 goto :err

echo [3/3] Exporting led_scan.bin / .hex / .lst ...
"%GCC_BIN%\riscv-none-elf-objcopy.exe" -R .storage -O binary led_scan.elf led_scan.bin
if errorlevel 1 goto :err
"%GCC_BIN%\riscv-none-elf-objcopy.exe" -O ihex led_scan.elf led_scan.hex
"%GCC_BIN%\riscv-none-elf-objdump.exe" -S led_scan.elf > led_scan.lst

echo.
echo ==== BUILD OK: led_scan.bin ====
dir led_scan.bin | findstr led_scan.bin
pause
exit /b 0

:err
echo.
echo !!! BUILD FAILED
pause
exit /b 1
