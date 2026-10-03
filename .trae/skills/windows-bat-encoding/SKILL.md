---
name: windows-bat-encoding
description: Write and repair Windows .bat files containing Chinese or other non-ASCII text. Use when creating or editing batch files, fixing question marks or mojibake such as GBK garbling, or making a bat work in both Explorer double-click and UTF-8 IDE terminals. Do not use for PowerShell-only scripts.
---

# Windows bat 编码（GB18030）规范与修复

## 何时使用

- 新建或修改任何含中文 / 非 ASCII 输出的 `.bat`
- bat 在资源管理器双击乱码（`'鍗曠嚎' 不是内部或外部命令` 类），或在 IDE 集成终端里中文显示 `?`
- 需要同一个 bat 在"资源管理器双击"和"IDE 集成终端运行"下都正常

## 铁律

1. 含非 ASCII 的 bat 一律 **GB18030、无 BOM、CRLF**，并在开头执行 `chcp 936 >nul`。
2. **控制语句保持纯 ASCII**（`if / for / goto / set / set /p`、路径等）；非 ASCII 只能出现在 `echo` / `REM` 之后，且不能处在会被拼接进命令的位置。
3. **不要采用"UTF-8 无 BOM + `chcp 65001`"**：中文 Windows 上 cmd 按系统代码页（936）预读文件块，切页来不及，中文行被切碎；多字节错位还会吞掉后续 `goto`（2026-10 在本机两种宿主下实测均碎）。
4. **编码守卫（兼容 IDE 终端）**：TRAE / VS Code 集成终端初始页是 65001，bat 切 936 后输出 GB 字节必显示 `?`。在 `@echo off` 之后、`chcp 936` 之前插入纯 ASCII 守卫行：

   ```bat
   chcp | find "65001" >nul && ( start "窗口标题" "%~f0" & exit /b 0 )
   ```

   从 IDE（65001）启动 → 自动开一个新的 936 控制台窗口重跑自己，IDE 窗口退出；资源管理器双击（初始即 936）→ 守卫不动作，原地运行。

## 写盘方法

- Write/Edit 工具**按文件原有编码写回**：GB 文件改完仍 GB，UTF-8 文件改完仍 UTF-8。
- **新建的 UTF-8 bat** → 转换：`powershell -File scripts/gbbat.ps1 -Path <bat路径>`
- **已经是 GB 的 bat** → 直接编辑即可，**不要再跑转换**（脚本会把 GB 字节当 UTF-8 读，洗成 `锟斤拷`）。
- 内容已损坏需重写 → PowerShell 单引号 here-string 组织内容，直接 GB 写盘：

  ```powershell
  $gb = [System.Text.Encoding]::GetEncoding(54936)
  $txt = ($content -replace "`r`n","`n") -replace "`n","`r`n"
  [System.IO.File]::WriteAllBytes($path, $gb.GetBytes($txt))
  ```

## 验证（必须做，不能跳过）

1. `powershell -File scripts/gbbat.ps1 -Path <bat路径> -Verify` → `BOM: False`、`lone LF: 0`
2. 用 GB18030 解码抽查一行中文，确认不是 `锟斤拷` / `??`
3. **资源管理器双击**运行：中文正常、控制流正常
4. IDE 集成终端运行：确认自动弹出新的 936 窗口（守卫生效）

## 故障对照表

| 现象 | 根因 | 处理 |
|---|---|---|
| IDE 终端中文全 `?` | 65001 终端显示 GB 字节 | 加守卫行；或资源管理器双击 |
| `'鍗曠嚎' 不是内部或外部命令` | UTF-8 文件被按 936 解析 | gbbat.ps1 转成 GB18030 |
| `锟斤拷` 类乱码 | GB 文件被当 UTF-8 重读重编码 | here-string 直接 GB 重写，勿再转换 |
| 中文行之后的 `goto`/命令丢失 | 多字节错位吞行 | 转 GB18030；控制语句行纯 ASCII |
| 守卫不弹窗 / `chcp` 无输出 | 守卫行位置不对或被改动 | 守卫必须在 `@echo off` 后、`chcp 936` 前，保持纯 ASCII |
