# ============================================================================
# CH32V003 单线调试 printf 监视器
#
# 固件通过 ch32v003fun DEBUGPRINTF 机制把 printf 字符打包写入调试模块的
# DATA0/DATA1 (DM reg 0x04/0x05), 经 SDI 单线 (PD1/SWDIO) 传出, 无需 UART 线。
# 本脚本不断轮询这两个寄存器并解码显示, 协议与 minichlink DefaultPollTerminal
# 完全一致:
#   DATA0:
#     bit7      = 有 printf 数据等待
#     bit0..3   = 字节数 (+4), 即 1..7
#     byte1..3  = 前 1..3 个字符
#   DATA1 byte0..3 = 第 4..7 个字符
#   读完后向 DATA0 写 0 作为主机应答
# ============================================================================

debug_level 1

init

# init 刚结束时目标状态可能是 "unknown" (首次 poll 还没跑), 此时直接
# resume 会因状态不是 halted 而被拒; 同时 DMCONTROL 的 haltreq 会一直
# 锁存, 用户按复位键芯片也会被立刻再次 halt。所以必须先显式 halt 让
# 状态确定, 再 resume。注意: 此 fork 用全局 halt/resume, 没有子命令。
set tn [lindex [target names] 0]
catch { halt }
after 200
catch { resume }

# 此 fork 的已知竞态: resume 可能报 "unable to resume" 但 dmstatus 稍后
# 显示 allrunning (核其实在跑, 只是没在 2.56ms 内回 resumeack)。
# 等 poll 拿到真实状态, 若确实还 halted 再补一次 resume。
after 200
if { [catch { $tn curstate } st] == 0 && $st eq "halted" } {
    after 100
    catch { resume }
    after 200
}

# 清掉 examine / 早期 printf 残留 (DATA0=0xc0 溢出锁存也要靠写 0 清除),
# 使单线 printf 通道处于空闲
catch { $tn riscv dmi_write 0x04 0 }

puts "============================================================"
puts " CH32V003 printf Monitor  (single-wire SDI / SWDIO)"
puts " Target state: [$tn curstate].  Close this window to stop."
puts " heartbeat every 2s. No output? check firmware is in normal mode"
puts "============================================================"
flush stdout

while {1} {
    set v  [ $tn riscv dmi_read 0x04 ]
    scan $v "%x" rr

    if { $rr & 0x80 } {
        set n [ expr { ($rr & 0x0f) - 4 } ]

        if { $n > 0 && $n <= 7 } {
            set s ""

            # 前最多 3 个字符在 DATA0 的 byte1..3
            set m $n
            if { $m > 3 } { set m 3 }
            for { set k 0 } { $k < $m } { incr k } {
                set c [ expr { ($rr >> (8 + $k * 8)) & 0xff } ]
                append s [ format "%c" $c ]
            }

            # 第 4 个及以后的字符在 DATA1 的 byte0..
            if { $n > 3 } {
                set v2 [ $tn riscv dmi_read 0x05 ]
                scan $v2 "%x" r2
                for { set k 0 } { $k < $n - 3 } { incr k } {
                    set c [ expr { ($r2 >> ($k * 8)) & 0xff } ]
                    append s [ format "%c" $c ]
                }
            }

            puts -nonewline $s
            flush stdout
        }

        # 主机应答: 清 DATA0, 固件即可发下一批
        $tn riscv dmi_write 0x04 0x00
        # 固件可能紧接着还有数据, 立刻再轮一次, 无数据时再休眠
        continue
    }

    after 15
}
