# CH32V003 烧录脚本 (WCH 安全增强版 OpenOCD)
# 必须用 page_erase: 该 fork 禁用了无地址的 range erase,
# page_erase 让写命令走 0x0b(按页边擦边写) 路径。
page_erase
init
halt
flash write_image led_scan/led_scan.bin 0x08000000 bin
verify_image led_scan/led_scan.bin 0x08000000
reset run
shutdown
