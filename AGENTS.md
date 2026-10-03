# AGENTS.md — CH32V003 项目上手指南

面向 AI 编程助手（也适用于人类）。读完本文即可独立完成本项目的编译、烧录、调试、单线 printf 监视，以及 SDI 被关闭后的救砖。

> ★ **维护规则（用户明确要求）**：本文是"活文档"。每次实机工作中得到**新的经验、踩了新的坑、发现新的硬件事实**，必须在当次工作结束前追加到第 8 节《经验追加记录》（带日期，一两句话写清现象→根因→做法），若属于长期规则则同步修订对应章节。不要等用户提醒。

## 1. 项目是做什么的

在 **CH32V003**（RISC-V QingKe V0 内核，16 KB Flash / 2 KB RAM）开发板上控制**板载红灯**，同时保留单线调试能力。

**已查明的关键硬件事实：红灯接在 PD1 上**（WCH CH32V003F4P6 官方板 LED1 = PD1/SWIO，ACTIVE_LOW，Zephyr 官方板文档同载；用户的 Cowramill 克隆板同款）。

因此 **PD1 一脚踏三职：红灯、SWDIO 调试线、单线 printf 通道，三者互斥**。当前固件 [led_scan.c](file:///c:/QGB/CH32V003/led_scan/led_scan.c) 的设计：

- **normal 模式（上电默认）**：SDI 保持常开，PD1 归调试模块，随时可烧录/监视；固件每 2 秒发一次 `alive n` 心跳
- **LED 模式（需武装）**：主机把两把魔数钥匙写入 SRAM 邮箱，固件检测到后才关闭 SDI（`AFIO->PCFR1` SWCFG=100），PD1 配推挽，红灯以 500 ms 间隔闪烁
- **断电即恢复**：邮箱在 SRAM 里，重新断电上电后钥匙丢失，SDI 自动恢复，**永远不需要救砖**（除非固件逻辑写错，见第 4.5 节）

## 2. 目录结构

```
c:\QGB\CH32V003\
├── led_scan\               # 红灯固件（当前主固件）
│   ├── led_scan.c          # 固件源码（normal/LED 双模式 + 武装邮箱）
│   ├── funconfig.h         # ch32fun 配置覆盖
│   ├── build_scan.bat      # 编译（纯 ASCII，编码无关）
│   └── led_scan.{elf,bin,hex,lst,map}   # 构建产物
├── led_blink\              # 最小点灯例程 + GDB 调试目标
│   ├── main.c / build.bat / ch32v003.gdb
├── ch32fun\                # 第三方库（上游 cnlohr/ch32fun，勿随意改；2026-10-03 由 ch32v003fun 改名）
│   └── ch32fun\ch32fun.{c,h}           # 启动文件、mini-printf、DEBUGPRINTF
│       注意: 库目录是 ch32fun, 内层核心目录也叫 ch32fun, 引用路径形如 ch32fun\ch32fun\ch32fun.h
│       led_blink\main.c 仍 #include "ch32v003fun.h", 由目录内同名兼容头转发到 ch32fun.h
├── wch-tools\              # ★ 全部工具链，项目自包含，不依赖系统安装
│   ├── openocd-wch\openocd-wch-ch32v003-bootfix-0.11.0-...\
│   │   ├── bin\openocd.exe
│   │   └── scripts\                        # OpenOCD -s 搜索目录（真实目录）
│   ├── xpack-riscv-none-elf-gcc-15.2.0-1\bin\
│   │   └── riscv-none-elf-{gcc,gdb,objcopy,objdump}.exe
│   └── ocd-src\                           # OpenOCD 源码（wlinke.c / wch_riscv-013.c，排查时查它）
├── ch32v003.cfg            # OpenOCD 目标配置（已修复，见第 6.3 条）
├── flash_wch.tcl           # 烧录脚本（擦除→写 bin→校验→reset run）
├── arm_led_mode.tcl        # 武装脚本（halt→写 SRAM 邮箱→resume→shutdown）
├── monitor_printf.tcl      # 单线 printf 监视器（OpenOCD Tcl 轮询脚本）
├── flash_led_scan.bat      # 双击：编译 + 烧录 + 询问是否占用 DIO
├── view_scan_printf.bat    # 双击：打开 printf 监视器
├── debug_v003.bat          # 双击：OpenOCD + GDB TUI 单步调试（调 led_blink）
├── debug_v003.ps1          # debug_v003.bat 的实际逻辑
└── .trae\skills\           # 项目级 skills
    └── windows-bat-encoding\   # bat GB18030 规范 / 65001 守卫 / gbbat.ps1
```

WCH-LinkUtility（官方 GUI，救砖用）已解压在：`C:\Users\Administrator\Desktop\WCH-LinkUtility\WCH-LinkUtility.exe`。

## 3. 硬件

- 调试器：**WCH-LinkE**，必须处于 **WCH-LinkRV 模式**（不是 ARM/DAP 模式；用 WCH-LinkUtility 切换，或按住 ModeS 插 USB）
- 接线（目标板 ↔ LinkE）只接 3 根：**SWDIO–PD1、GND、3V3**（单线调试只走 SWDIO 一根信号线；SWCLK/PD2、NRST/PD7 都不接）
- 板上按键 = 复位键（PD7/NRST，板上有 100 kΩ 上拉，标"01D"）
- 设备：VID_1A86 PID_8010，WCH 原生驱动（WCHLinkW64.SYS / 服务 WCHLink_A64）
- 板子供电必须由 **LinkE 的 3V3 引脚提供**——这不只是约定，更是掉电救砖法的物理前提（见 4.5）
- 排线尽量短（≤15 cm，救砖时越短越好，实测 5 cm）；SWDIO 脚不要外接灯珠/上下拉（红灯是板载既成事实，软件规避）
- 高仿/偷工 LinkE 可能缺少电源开关件 CH217K，表现为能烧录但"断电清空"永远失败（灯不灭），只能换正品 LinkE

## 4. 标准流程

### 4.1 编译 + 烧录 + 询问是否占用 DIO（面向用户）

运行 `flash_led_scan.bat`：资源管理器双击，或在 IDE 集成终端里运行（IDE 下会自动弹出新的 936 控制台窗口，见第 6.8 条）。流程：编译 → OpenOCD 烧录（page_erase 边擦边写 + 校验 + `reset run`）→ 询问：

```
是否现在占用 DIO 点亮红灯? Y=占用 N=保持调试口(断电自动恢复):
```

- 输入 **N**：固件停在 normal 模式，SDI 常开，可用监视器看心跳
- 输入 **Y**：自动调用 [arm_led_mode.tcl](file:///c:/QGB/CH32V003/arm_led_mode.tcl)，约 1 秒内红灯 0.5 秒间隔闪烁；此时烧录/监视连不上**属正常**，给板子**断电重新上电**即恢复

手动等价命令：

```powershell
$OCD = "C:\QGB\CH32V003\wch-tools\openocd-wch\openocd-wch-ch32v003-bootfix-0.11.0-ch32v003bootfix.3-windows-x86-wchdriver"
# 烧录
& "$OCD\bin\openocd.exe" -s "$OCD\scripts" -f C:\QGB\CH32V003\ch32v003.cfg -f C:\QGB\CH32V003\flash_wch.tcl
# 武装（可选）
& "$OCD\bin\openocd.exe" -s "$OCD\scripts" -f C:\QGB\CH32V003\ch32v003.cfg -f C:\QGB\CH32V003\arm_led_mode.tcl
```

当前固件大小：FLASH 2112 B / 16 KB（12.89%），RAM 0 B。

### 4.2 武装机制（改代码时必须保持一致）

邮箱地址 / 钥匙在固件与 tcl 两边必须完全相同：

| SRAM 地址 | 值 | ASCII |
|---|---|---|
| `0x20000700` | `0x57434831` | "WCH1" |
| `0x20000704` | `0x4c454431` | "LED1" |

- 选 `0x20000700` 是因为栈顶在 `0x20000800`，留了 256 字节余量；改固件后要重新确认 map 里此地址无占用
- 随机 RAM 同时等于两把钥匙的概率可忽略，故无需上电清零
- 武装路径上不要再 printf（SDI 马上关，主机收不到还白等超时）；固件**只在轮询到双钥匙后**才写 AFIO 关 SDI

### 4.3 单线 printf 监视

双击 `view_scan_printf.bat`。当前固件的实际输出：

```
PD1 LED fw, SDI open, arm to blink
alive 1
alive 2
alive 3
...
```

心跳每 2 秒一个；监视器最迟 2 秒内必见输出。关窗口即停止；启动前 bat 自动 `taskkill openocd.exe`（LinkE 同一时刻只允许一个连接）。

### 4.4 GDB 单步调试

双击 `debug_v003.bat`：OpenOCD GDB Server（:3333）+ `riscv-none-elf-gdb -tui`，目标是 **led_blink**（`led_blink\ch32v003.gdb`，工作目录 led_blink）。

### 4.5 ★ 救砖：SDI 被固件关闭后如何恢复（已实战验证）

**背景教训**：旧版固件上电 2.5 秒后无条件关 SDI，曾导致无法重烧。当时尝试的两条路都不可行，**不要再走**：

- ❌ 按住复位键时连接 / 主机反复 openocd 盲试：连接握手需芯片运行，复位态必败；单次 openocd 启动+USB 往返远超窗口，60 次盲试零命中
- ✅ **正确做法：WCH-LinkUtility 的"断电清空"**。LinkE 固件在内部完成"切断目标 3V3 → 上电 → 在启动窗口内立即连接并全擦"，时序不经过电脑，确定性成功

步骤（WCH-LinkUtility V3.10）：

1. 顶部：存储器类型=内置，内核=RISC-V，**系列=CH32V003**，地址 0x8000000
2. 操作：**只勾「全擦」**，取消「下载」（目标文件路径无效会报错）、取消「校验」
3. **CLK 速度改「低」**
4. 勾选 **「设置硬件掉电延时(0~30ms)」**，填 `10`（失败再试 `30`）
5. 其他选项一律不动（"使能外部复位引脚"下拉、BOOT 区启动、WRP 等保持默认）
6. 点左下角蓝色圆形执行按钮

判据：执行瞬间**红灯应完全灭一下**（LinkE 切掉了电源）。灯不灭 = 供电没走 LinkE 或 LinkE 缺电源开关件。擦除成功后芯片空白、SDI 恢复常开，再按 4.1 烧新固件。

## 5. 单线 printf 机制（DEBUGPRINTF）

- 固件的 `printf` 是 ch32fun 自带 **mini-printf**（`ch32fun.c`），回调 `_write()` 把字符打包写入调试模块寄存器，经 SDI 单线（PD1/SWDIO）传出
- 固件侧 CPU 地址：DATA0=`0xe00000f4`，DATA1=`0xe00000f8`，SENTINEL=`0xe00000fc`
- 数据包协议（与 minichlink `DefaultPollTerminal` 一致）：
  - DATA0 低字节：bit7=数据等待；bit0–3=字节数+4（n=1..7）；byte1–3=前 3 个字符
  - DATA1：byte0 起=第 4–7 个字符
  - 主机取走数据后向 **DATA0 写 0 应答**，固件才发下一包
  - 每包等待约 200 ms（`FUNCONF_DEBUGPRINTF`），超时则 DATA0 置 `0xc0`，之后 printf 快速丢弃，直到主机写 0 清除
- `monitor_printf.tcl` 用 `$target riscv dmi_read 0x04/0x05` 轮询、`dmi_write 0x04 0` 应答，15 ms 空闲轮询

## 6. ★ 必须遵守的规则与已知坑

1. **所有含中文的 bat 必须存为 GB18030（无 BOM，CRLF），首行 `chcp 936`。**
   UTF-8 落盘会被 CMD 按 936 切碎，出现 `'鍗曠嚎' 不是内部或外部命令` 之类乱码。纯 ASCII bat（如 build_scan.bat）编码无关。转码：

   ```powershell
   $gb = [System.Text.Encoding]::GetEncoding(54936)
   $txt = [System.IO.File]::ReadAllText($path, (New-Object System.Text.UTF8Encoding($false)))
   $txt = ($txt -replace "`r`n","`n") -replace "`n","`r`n"   # 顺手统一 CRLF
   [System.IO.File]::WriteAllBytes($path, $gb.GetBytes($txt))
   ```

   bat 内**控制语句保持纯 ASCII，中文只能出现在 `echo`/`REM` 后面**。

   ★ **Write/Edit 工具会按文件的原有编码写回**（GB 文件改完还是 GB，UTF-8 文件改完还是 UTF-8）。改完 bat 不要盲目再跑一遍"按 UTF-8 读→GB 写"，那会把本来的 GB 文件洗成 `锟斤拷`。最稳路径：PowerShell 单引号 here-string 组织内容 → 直接 GB 写盘 → 再用 GB 解码抽查关键行。

2. **mini-printf 不支持宽度/对齐/长度修饰符**：`%2lu`、`%-3s` 会乱码并导致参数错位。只用朴素的 `%d %u %s %x %c %%`。

3. **ch32v003.cfg 的 target 创建写法**（曾导致烧录全败）：

   ```tcl
   set _CHIPNAME wch_riscv
   sdi newtap $_CHIPNAME cpu -irlen 5 -expected-id 0x00001
   set _TARGETNAME $_CHIPNAME.cpu
   target create $_TARGETNAME.0 wch_riscv -chain-position $_TARGETNAME
   ```

   `-chain-position` 必须是 `$_TARGETNAME`（wch_riscv.cpu），**不是 `$_CHIPNAME`**。work-area：`0x20000000` size `10000` backup 1；flash bank：user `wch_riscv 0x08000000 0x4000`，boot `0x1ffff000 0x1000`。官方参考：OpenOCD 包内 `share\openocd\scripts\target\wch-riscv-ch32v003.cfg`。

4. **OpenOCD Tcl 命令路径（此 WCH fork 的特殊点）**：
   - 没有 `$target resume`/`$target halt`——用**全局** `resume`/`halt`
   - DMI 访问：`$target riscv dmi_read <addr>` / `dmi_write <addr> <val>`（riscv 子命名空间）
   - 寄存器：`$target get_reg list`
   - LinkE 配置期还暴露了 `pow3v3 on|off`、`pow5v`、`rst_set 0|1|2`、`code_erase`、`page_erase` 等命令（COMMAND_CONFIG，见 wlinke.c 命令注册表）

5. **监视器启动序列必须 `halt` → `resume`**：`init` 后目标状态是 `unknown`，直接 resume 会被拒；更糟是 DMCONTROL 的 haltreq 锁存后，用户按复位键芯片也会被立刻再 halt。修法：`catch {halt}; after 200; catch {resume}`，再清 DATA0。该问题 stdout 重定向时因 poll 快被掩盖，**必须在真实双击的控制台验证**。

6. **resume 竞态（假失败，已解码）**：监视器可能报 `unable to resume, dmstatus=0x004c0c82`。该值含 allrunning/anyrunning——核其实已运行，只是没在驱动的 2.56 ms 判定窗内回 resumeack。**处理：不慌，等 200 ms 查 `$tn curstate`，确为 halted 才补 resume**（monitor_printf.tcl 已按此实现）。

7. **printf 不能只打一次性横幅**：无主机时横幅打印完即被丢弃，之后接入的监视器永远黑屏，会被用户判为"没作用"。需要被随时观察的固件**必须周期心跳**（本固件 2 秒）。同时横幅/打印串尽量短——无主机时每个丢弃包阻塞约 200 ms，长横幅会把武装检测推迟数秒。

8. **IDE 集成终端里的中文 `?` 与编码自适应守卫（已实测）**：IDE 终端初始页 65001，bat 里 `chcp 936` 后输出 GB 字节必显示 `?`。而"UTF-8 无 BOM + `chcp 65001`"的 bat 在本机实验下两条路都碎——cmd 按系统代码页(936)预读文件块，切页来不及，中文行被切碎甚至吞掉后续 `goto`。正解是守卫行（放在 `@echo off` 之后、`chcp 936` 之前，本身纯 ASCII）：

   ```bat
   chcp | find "65001" >nul && ( start "窗口标题" "%~f0" & exit /b 0 )
   ```

   从 UTF-8 宿主（IDE）启动 → 自动开一个新的 936 控制台窗口重跑自己，IDE 窗口退出；资源管理器双击（初始即 936）→ 守卫不动作，原地运行。`flash_led_scan.bat`、`view_scan_printf.bat` 均已安装。

9. **不要在 main 里显式调用 `SetupDebugPrintf()`**：此版本 `SystemInit()` 已自动调用且头文件未导出声明，显式调用编译报错。

10. **minichlink 在此机器不可用**：WCH 原生驱动不暴露 WinUSB，`minichlink -T` 报 libusb -5。终端只用本项目 OpenOCD + monitor_printf.tcl。

11. 环境无 git；改固件后必须重新编译烧录，`reset run` 立即生效。提交/版本管理类操作需用户明确要求。

## 7. 给 AI 助手的工作建议

- 改动固件：编辑 led_scan\led_scan.c（或 led_blink\main.c）→ build bat → 烧录 → 监视器验证心跳/动作。用户有硬件在场，可要求观察 LED
- **任何新固件默认上电一律不许关 SDI/碰 PD1**；占用 DIO 只能走"主机武装 + SRAM 钥匙 + 断电恢复"模式（第 4.2 节）
- 新建/修改含中文 .bat 后按 6.1 转 GB18030，并提醒用户资源管理器双击实跑
- 不要创建多余文件；临时诊断/救援脚本用完即删（历史上 rescue_flash.tcl/bat、rescue2_flash.tcl/bat 已删除）
- 异常先查：残留 openocd 占线、LinkE 是否 WCH-LinkRV、接线 SWDIO/GND/3V3、排线长度
- **工作结束前：把本次新经验按第 8 节格式追加；涉及长期规则的同步改正文**

## 8. 经验追加记录（新经验自动写这里，最新在上）

> 格式：`YYYY-MM-DD｜现象 → 根因 → 做法`。简短即可，详情进正文对应章节。

- 2026-10-03｜第三方库目录 ch32v003fun 改名为 ch32fun（对齐上游 cnlohr/ch32fun）→ 同步改两个 build bat、build.sh（含 git clone URL）、Makefile（顺带把失效的绝对路径改成 ../ch32fun/ch32fun）、ch32v003.gdb；debug_v003.bat/.ps1 与 flash/view bat 不含库路径无需改；两项目重新编译通过；库内部文件（README/examples/package.json）属第三方不动
- 2026-10-03｜创建项目级 skill `windows-bat-encoding`（`.trae\skills\`）→ 沉淀 GB18030 bat 规范、65001 守卫与 gbbat.ps1 转换/校验脚本（两种模式均实跑通过）→ 遇 bat 编码问题由该 skill 触发
- 2026-10-03｜对已是 GB 的 bat 重跑"UTF-8 读→GB 写"，中文变 `锟斤拷` → Write/Edit 工具按文件原编码写回，转码脚本误读了 GB 字节 → 改用 PowerShell here-string 直接 GB 写盘 + GB 解码抽查（见 6.1）
- 2026-10-03｜IDE 终端跑 bat 中文全 `?`；UTF-8+chcp65001 方案实测也碎（cmd 按系统 936 预读文件块，切页来不及，还吞 goto）→ bat 开头加 `chcp|find 65001` 守卫，自动开新 936 窗口重跑自己，双击则原地运行（见 6.8）
- 2026-10-03｜bat 在 TRAE 集成终端运行时中文全显示 `?????` → IDE 终端按 UTF-8 解码 GB18030 字节 → 一律要求资源管理器双击（见 6.8）【已被守卫方案取代，保留存档】
- 2026-10-03｜监视器报 `unable to resume dmstatus=0x004c0c82` 但随后显示 running → WCH DM 没在 2.56 ms 窗内回 resumeack 的竞态 → 等待后查 curstate，仅 halted 才补 resume（见 6.6）
- 2026-10-03｜监视器连接后无任何输出被判定"没作用" → 一次性横幅早被丢弃，固件之后静默 → 固件加 2 秒周期心跳，打印串保持短（见 6.7）
- 2026-10-03｜SDI 被固件关闭，60 次复位盲试全败 → 主机侧 USB 往返赶不上启动窗口，复位态又无法握手 → WCH-LinkUtility 勾选"设置硬件掉电延时 10ms"+只全擦+CLK 低，LinkE 固件内部断电上电擦除（见 4.5）
- 2026-10-03｜确认板载红灯引脚 = PD1/SWDIO（ACTIVE_LOW），与调试口互斥 → 15 脚扫描时灯不闪即因此 → 固件做 normal/LED 双模式，SRAM 双钥匙武装，断电自动恢复（见第 1、4.2 节）
