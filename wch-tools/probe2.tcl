init
halt
set rcc     [read_memory 0x40021018 32 1]
set cfglr   [read_memory 0x40011400 32 1]
set outdr1  [read_memory 0x4001140c 32 1]
set systick [read_memory 0xe000f008 32 1]
set v0      [read_memory 0x00000000 32 1]
set v1      [read_memory 0x00000004 32 1]
resume
sleep 600
halt
set outdr2 [read_memory 0x4001140c 32 1]
set pc2 [reg pc]
echo "RESULT APB2PCENR=0x$rcc CFGLR=0x$cfglr"
echo "RESULT OUTDR1=0x$outdr1 OUTDR2=0x$outdr2 PC2=$pc2"
echo "RESULT SysTickCNT=0x$systick Vec0=0x$v0 Vec1=0x$v1"
shutdown
