init
halt
resume
for {set i 0} {$i < 10} {incr i} {
    halt
    set a [read_memory 0x4001080c 32 1]
    set c [read_memory 0x4001100c 32 1]
    set d [read_memory 0x4001140c 32 1]
    set pc [reg pc]
    echo "RESULT SAMPLE$i A=0x$a C=0x$c D=0x$d PC=$pc"
    resume
    sleep 200
}
shutdown
