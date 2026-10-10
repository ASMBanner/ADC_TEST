/**
 ****************************************************************************************************
 * @file        syscalls.c
 * @brief       newlib (GCC) 系统调用桩函数
 *
 *              作用：
 *              1. 替代 --specs=nosys.specs 的默认空桩，消除链接器
 *                 "_write/_read/_close/_fstat/_isatty/_lseek is not implemented" 警告；
 *              2. 将 _write 重定向到 USART1，使 printf 真正可以从串口输出
 *                 （Keil 下靠 fputc 重定向，newlib 下则是走 _write）；
 *              3. 提供 _sbrk 供 malloc 使用（堆位于 ._user_heap_stack 区）。
 ****************************************************************************************************
 */

#include <stddef.h>
#include <stdint.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "stm32f4xx.h"


/**
 * @brief       串口输出（printf 最终会调用到这里）
 * @param       file: 文件描述符（未使用）
 * @param       ptr : 待发送数据缓冲区
 * @param       len : 数据长度
 * @retval      实际写入的字节数
 */
int _write(int file, char *ptr, int len)
{
    int i;

    (void)file;

    for (i = 0; i < len; i++)
    {
        while ((USART1->SR & USART_SR_TXE) == 0);   /* 等待发送数据寄存器为空 */
        USART1->DR = (uint8_t)ptr[i];               /* 写入数据寄存器 */
    }

    return len;
}

/**
 * @brief       读取（本工程未使用）
 */
int _read(int file, char *ptr, int len)
{
    (void)file;
    (void)ptr;
    (void)len;
    return 0;
}

/**
 * @brief       关闭文件（本工程未使用）
 */
int _close(int file)
{
    (void)file;
    return -1;
}

/**
 * @brief       文件状态（标准输出按字符设备处理）
 */
int _fstat(int file, struct stat *st)
{
    (void)file;
    st->st_mode = S_IFCHR;
    return 0;
}

/**
 * @brief       判断是否为终端设备
 */
int _isatty(int file)
{
    (void)file;
    return 1;
}

/**
 * @brief       文件定位（本工程未使用）
 */
int _lseek(int file, int ptr, int dir)
{
    (void)file;
    (void)ptr;
    (void)dir;
    return 0;
}

/**
 * @brief       堆内存扩展（供 malloc / new 使用）
 * @param       incr: 需要扩展的字节数
 * @retval      扩展前的堆顶地址；失败返回 (caddr_t)-1
 * @note        堆起始地址由链接脚本的 end 符号给出，上限为当前栈指针。
 */
caddr_t _sbrk(int incr)
{
    extern char end;                    /* 链接脚本中定义：堆起始地址 */

    static char *heap_end = 0;
    char *prev_heap_end;
    uint32_t sp;

    __asm volatile ("mov %0, sp" : "=r" (sp));      /* 读取当前栈指针 */

    if (heap_end == 0)
    {
        heap_end = &end;
    }

    prev_heap_end = heap_end;

    if ((uint32_t)(heap_end + incr) > sp)           /* 与栈空间冲突则失败 */
    {
        errno = ENOMEM;
        return (caddr_t) -1;
    }

    heap_end += incr;
    return (caddr_t) prev_heap_end;
}
