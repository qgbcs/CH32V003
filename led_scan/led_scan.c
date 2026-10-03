// ============================================================================
// CH32V003 板载红灯固件 (PD1 = SWDIO, 与单线调试口共用)
//
// 结论来源: WCH CH32V003F4P6 官方板红灯 LED1 = PD1/SWIO (ACTIVE_LOW),
//           Zephyr 官方板文档同载; Cowramill 为同款克隆。
//
// ★ 设计 (上电不允许立马占用 DIO):
//   1. 上电默认保持 SDI 常开, PD1 归调试模块, 可随时烧录 / 单线 printf。
//   2. 主机用 arm_led_mode.tcl 往 SRAM 武装邮箱写入两把 32 位魔数钥匙,
//      固件检测到后才关闭 SDI (AFIO->PCFR1 SWCFG=100), 把 PD1 配成推挽,
//      以 500ms 间隔闪红灯。
//   3. 邮箱内容掉电即丢失 -> 重新断电上电, SDI 自动恢复, 无需任何救砖操作。
//      (随机 RAM 恰好同时等于两把钥匙的概率可忽略)
// ============================================================================

#include "ch32fun.h"
#include <stdio.h>

#define LED_PIN     1      // PD1
#define BLINK_MS    500    // 亮/灭各 500ms

// SRAM 武装邮箱: 固定地址, 距栈顶 (0x20000800) 留 256 字节余量, 不会被栈踩
#define ARM_MAILBOX0   (*(volatile uint32_t *)0x20000700u)
#define ARM_MAILBOX1   (*(volatile uint32_t *)0x20000704u)
#define ARM_KEY0       0x57434831u   // "WCH1"
#define ARM_KEY1       0x4c454431u   // "LED1"

#define AFIO_SWCFG_MASK     0x07000000u
#define AFIO_SWCFG_SWD_OFF  0x04000000u

// 检测到武装钥匙后调用: 关闭 SDI, PD1 闪红灯, 不返回
static void enter_led_mode(void)
{
    // 此处不再 printf: SDI 马上关闭, 主机收不到且会白等打印超时。

    // --- 关闭 SDI, 释放 PD1/PD2 为普通 GPIO ---
    AFIO->PCFR1 = (AFIO->PCFR1 & ~AFIO_SWCFG_MASK) | AFIO_SWCFG_SWD_OFF;

    // --- PD1 配推挽输出 ---
    uint32_t sh = (uint32_t)LED_PIN * 4u;
    GPIOD->CFGLR &= ~(0xFu << sh);
    GPIOD->CFGLR |= (uint32_t)(GPIO_Speed_10MHz | GPIO_CNF_OUT_PP) << sh;

    uint32_t mask = 1u << LED_PIN;
    GPIOD->BCR = mask;   // 先低 (红灯灭)

    for (;;)
    {
        GPIOD->BSHR = mask;   // 高 -> 红灯亮
        Delay_Ms(BLINK_MS);
        GPIOD->BCR  = mask;   // 低 -> 红灯灭
        Delay_Ms(BLINK_MS);
    }
}

int main(void)
{
    SystemInit();

    RCC->APB2PCENR |= RCC_APB2Periph_GPIOD | RCC_APB2Periph_AFIO;

    // 横幅刻意短: 无主机时每个丢弃包阻塞约 200ms, 太长会推迟武装检测
    printf("\nPD1 LED fw, SDI open, arm to blink\n");

    // 每 2 秒发一次心跳, 让随时接入的监视器在 2 秒内看到输出
    // (启动横幅若在无主机时打印会被丢弃, 不能只靠横幅)
    uint32_t tick = 0;
    uint32_t beats = 0;
    for (;;)
    {
        if ((ARM_MAILBOX0 == ARM_KEY0) && (ARM_MAILBOX1 == ARM_KEY1))
            enter_led_mode();   // 不返回
        Delay_Ms(20);
        if (++tick >= 100)      // 100 x 20ms = 2s
        {
            tick = 0;
            printf("alive %u\n", (unsigned)(++beats));
        }
    }
}
