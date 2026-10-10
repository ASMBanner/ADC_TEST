/**
 ***************************************************************************************************
 * 一、实验简介
 * 实验名称：单通道ADC采集 实验
 * 实验平台：STM32F407开发板（MCU：STM32F407，Cortex-M4，主频168MHz）
 * 实验目的：学习STM32内部ADC的使用，掌握ADC单通道采样、均值滤波及电压换算方法

 ***************************************************************************************************
 * 二、硬件资源及引脚分配
 * 1 LED灯
     DS0（RED）     : LED0 - PF9
     DS1（GREEN）   : LED1 - PF10
 * 2 串口1(PA9/PA10连接在板载USB转串口芯片CH340上面)
 * 3 2.8/3.5/4.3/7/10寸TFTLCD模块(仅限MCU屏，16位8080并口驱动，FSMC接口)
 * 4 ADC1  : 通道5 - PA5（模拟输入，可接RV1可调电阻中心抽头）
 * 5 调试接口 : J-Link SWD（SWDIO/SWCLK），用于固件烧录与在线仿真调试

 ***************************************************************************************************
 * 三、程序工程结构
 * ADC_TEST/
 * ├── build.sh                  GCC 一键编译脚本（arm-none-eabi-gcc）
 * ├── flash.sh                  J-Link 固件烧录脚本
 * ├── debug.sh                  J-Link + GDB 在线仿真调试脚本
 * ├── setup_debug.sh            一键生成 VS Code 调试配置（.vscode/*）
 * ├── User/                     用户应用层
 * │   ├── main.c                主程序（初始化、ADC采样、LCD显示、LED闪烁）
 * │   ├── stm32f4xx_it.c/.h     中断服务函数（SysTick等）
 * │   ├── stm32f4xx_hal_conf.h  HAL 库配置头文件（裁剪使用的HAL模块）
 * │   └── syscalls.c            GCC newlib 系统调用桩（重定向printf等）
 * ├── Drivers/
 * │   ├── BSP/                  板级支持包驱动
 * │   │   ├── ADC/adc.c/.h      ADC 驱动（ADC1通道5，采样与均值滤波）
 * │   │   ├── LED/led.c/.h      LED 驱动
 * │   │   └── LCD/              LCD 驱动（lcd.c/lcd_ex.c/lcdfont.h，16位8080并口）
 * │   ├── SYSTEM/               系统核心驱动
 * │   │   ├── sys/sys.c/.h      时钟配置、系统初始化
 * │   │   ├── delay/            滴答延时
 * │   │   └── usart/            串口驱动（printf重定向）
 * │   ├── CMSIS/                ARM CMSIS 内核头文件、设备头文件、启动文件
 * │   └── STM32F4xx_HAL_Driver/ ST 官方 HAL 库源码与头文件
 * ├── Middlewares/              中间件目录（预留，本实验未使用）
 * ├── Projects/
 * │   ├── MDK-ARM/              Keil uVision5 工程（atk_f407.uvprojx）
 * │   └── GCC/                  GCC 工程文件
 * │       ├── startup_stm32f407xx.s    GCC 启动文件
 * │       └── STM32F407XX_FLASH.ld     GCC 链接脚本（Flash/RAM 分配）
 * ├── Output/                   编译输出目录（执行 build.sh 后生成）
 * │   └── atk_f407.elf/.bin/.hex/.map
 * └── .vscode/                  VS Code 编译/调试配置（settings/tasks/launch.json）

 ***************************************************************************************************
 * 四、程序设计说明
 * 1 初始化流程（main.c）：
 *   HAL_Init() → sys_stm32_clock_init(336, 8, 2, 7)（系统时钟168MHz）
 *   → delay_init(168) → usart_init(115200) → led_init() → lcd_init() → adc_init()
 * 2 ADC 配置（adc.c）：
 *   ADC1，12位精度，右对齐；ADCCLK = PCLK2/4 = 21MHz；
 *   软件触发、单次转换、非扫描模式、无DMA；
 *   采样时间取480个ADC时钟周期，单次转换时间 = (480+12)/21M ≈ 23.4us。
 * 3 采样与滤波：
 *   adc_get_result() 轮询方式获取单次转换结果；
 *   adc_get_result_average(ch, times) 连续采样 times 次取平均（本实验取10次）。
 * 4 电压换算：
 *   电压值 = 采样值 × (3.3 / 4096)，在LCD上分别显示整数部分与3位小数部分。
 * 5 主循环：每约100ms采样刷新一次LCD显示，并翻转LED0指示程序运行。

 ***************************************************************************************************
 * 五、编译说明
 * 方式一：GCC 命令行编译（macOS/Linux）
 *   ./build.sh          # 增量编译，生成 Output/atk_f407.elf/.bin/.hex/.map
 *   ./build.sh clean    # 清理编译产物
 *   说明：源文件列表、包含路径、宏定义与 Keil 工程保持一致；
 *         需安装 arm-none-eabi-gcc 工具链（脚本找不到时会尝试内置默认路径）。
 * 方式二：Keil MDK 编译（Windows）
 *   打开 Projects/MDK-ARM/atk_f407.uvprojx，直接编译即可。
 * 方式三：VS Code 编译
 *   执行任务 "build"（Terminal → Run Task，对应 build.sh），"clean" 用于清理。

 ***************************************************************************************************
 * 六、仿真调试说明（J-Link 仿真器，SWD 接口）
 * 1 命令行在线仿真调试：
 *   ./debug.sh
 *   流程：启动 JLinkGDBServer → arm-none-eabi-gdb 连接 → 下载固件 → 复位停在 main，
 *         随后可直接使用 gdb 命令（break / continue / next / step / print 等）调试。
 *   可用环境变量：JLINK_DEVICE（默认 STM32F407ZG）、JLINK_SPEED（默认 4000）、
 *                 GDB_PORT（默认 2331）、GDB_SERVER_EXTERNAL=1（复用已启动的GDB Server）。
 * 2 烧录固件（不进入调试）：
 *   ./flash.sh          # 通过 J-Link 烧录 hex 并复位运行
 * 3 VS Code 图形化仿真调试：
 *   ./setup_debug.sh    # 生成 .vscode 调试配置（仅需执行一次）
 *   安装 Cortex-Debug 插件后，按 F5 选择
 *   "J-Link 调试 (STM32F407)"（自动先编译再下载调试）
 *   或 "J-Link 调试 (不重新编译)"（直接调试已有固件），
 *   支持断点、单步、变量/寄存器/外设查看、SWO 日志等调试功能。

 ***************************************************************************************************
 * 七、实验现象
 * 1 ADC1读取通道5（PA5）上面的电压，在LCD模块上面显示ADC转换值以及换算成电压后的电压值。
 * 2 可以用杜邦线将ADC接到RV1标号的可调电阻上，通过螺丝刀调节RV1可变电阻端的电压测量ADC结果。
 * 3 LED0闪烁，提示程序运行。

 ***************************************************************************************************
 * 八、注意事项
 * 1 电脑端串口调试助手波特率必须是115200
 * 2 请使用SSCOM串口调试助手,其他串口助手可能控制DTR/RTS导致MCU复位/程序不运行
 * 3 串口输入字符串以回车换行结束
 * 4 请用USB线连接在USB_UART,找到USB转串口后测试本例程
 * 5 P10的PA9/PA10必须通过跳线帽连接在RXD/TXD上
 * 6 本例程仅支持MCU屏，不支持RGB屏
 * 7 4.3寸和7寸屏需要比较大电流,USB供电可能不足,请用外部电源适配器(推荐外接12V 1A电源).
 * 8 由于是使用STM32引脚直接测量，ADC请连接到0-3.3V之间的测试电源，否则容易烧坏芯片
 * 9 仿真调试前请确保 J-Link 已通过 SWD 连接开发板并安装 SEGGER J-Link 软件包
 * 10 GCC 编译需安装 arm-none-eabi-gcc 工具链；若安装路径特殊，请修改 build.sh / debug.sh
 *    中的工具链路径配置

 */
