#include "ch32v003fun.h"
#include <stdio.h>

int main(void)
{
    // ch32v003fun 提供的系统时钟初始化
    SystemInit();

    // 1. 开启 GPIOD 端口的时钟
    RCC->APB2PCENR |= RCC_APB2Periph_GPIOD;

    // 2. 配置 PD4 为推挽输出，10MHz 速度
    // 先清除 PD4 的配置寄存器位
    GPIOD->CFGLR &= ~(0xF << (4 * 4));
    // 写入模式配置
    GPIOD->CFGLR |= (GPIO_Speed_10MHz | GPIO_CNF_OUT_PP) << (4 * 4);

    while(1)
    {
        // PD4 置高电平
        GPIOD->BSHR = (1 << 4);
        Delay_Ms(500);

        // PD4 置低电平 (复位)
        GPIOD->BCR = (1 << 4);
        Delay_Ms(500);
    }
}