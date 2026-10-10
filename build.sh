#!/usr/bin/env bash
# =============================================================================
# build.sh —— STM32F407 (探索者) 工程 GCC 编译脚本
#
# 功能：使用 arm-none-eabi-gcc 编译整个工程，生成
#         Output/atk_f407.elf / atk_f407.bin / atk_f407.hex
#
# 用法：
#   ./build.sh          # 增量编译
#   ./build.sh clean    # 清理编译产物
#
# 说明：源文件列表、包含路径、宏定义均取自
#       Projects/MDK-ARM/atk_f407.uvprojx，与 Keil 工程保持一致。
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 0. 路径设置
# ---------------------------------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/Output/obj"
OUT_DIR="$ROOT_DIR/Output"
LD_SCRIPT="$ROOT_DIR/Projects/GCC/STM32F407XX_FLASH.ld"
TARGET="atk_f407"

# ---------------------------------------------------------------------------
# 1. 清理
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "clean" ]]; then
    echo ">> 清理编译产物 ..."
    rm -rf "$BUILD_DIR"
    rm -f "$OUT_DIR/$TARGET.elf" "$OUT_DIR/$TARGET.bin" "$OUT_DIR/$TARGET.hex" "$OUT_DIR/$TARGET.map"
    echo ">> 完成"
    exit 0
fi

# ---------------------------------------------------------------------------
# 2. 定位工具链
# ---------------------------------------------------------------------------
if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
    TOOLCHAIN_PREFIX="arm-none-eabi-"
else
    # 常见本地安装路径，若不在 PATH 中则尝试使用
    CANDIDATES=(
        "/Users/banner/Work/K3PT/.tools/arm-gnu-toolchain-15.2.rel1-darwin-arm64-arm-none-eabi/bin"
    )
    for c in "${CANDIDATES[@]}"; do
        if [[ -x "$c/arm-none-eabi-gcc" ]]; then
            export PATH="$c:$PATH"
            break
        fi
    done
    TOOLCHAIN_PREFIX="arm-none-eabi-"
fi

CC="${TOOLCHAIN_PREFIX}gcc"
OBJCOPY="${TOOLCHAIN_PREFIX}objcopy"
SIZE="${TOOLCHAIN_PREFIX}size"

if ! command -v "$CC" >/dev/null 2>&1; then
    echo "错误：找不到 $CC，请安装 arm-none-eabi-gcc 工具链并加入 PATH。" >&2
    exit 1
fi

echo ">> 工具链: $($CC --version | head -n 1)"

# ---------------------------------------------------------------------------
# 3. 源文件列表（与 Keil 工程一致）
# ---------------------------------------------------------------------------
SOURCES=(
    "$ROOT_DIR/Projects/GCC/startup_stm32f407xx.s"
    "$ROOT_DIR/User/main.c"
    "$ROOT_DIR/User/stm32f4xx_it.c"
    "$ROOT_DIR/User/syscalls.c"
    "$ROOT_DIR/Drivers/CMSIS/Device/ST/STM32F4xx/Source/Templates/system_stm32f4xx.c"
    "$ROOT_DIR/Drivers/SYSTEM/delay/delay.c"
    "$ROOT_DIR/Drivers/SYSTEM/sys/sys.c"
    "$ROOT_DIR/Drivers/SYSTEM/usart/usart.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_cortex.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_dma.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_gpio.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_rcc.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_rcc_ex.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_usart.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_pwr.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_pwr_ex.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_uart.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_dma_ex.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_sram.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_ll_fsmc.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_adc_ex.c"
    "$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Src/stm32f4xx_hal_adc.c"
    "$ROOT_DIR/Drivers/BSP/LED/led.c"
    "$ROOT_DIR/Drivers/BSP/LCD/lcd.c"
    "$ROOT_DIR/Drivers/BSP/ADC/adc.c"
)

# ---------------------------------------------------------------------------
# 4. 包含路径 / 宏定义 / 编译选项
# ---------------------------------------------------------------------------
INCLUDES=(
    "-I$ROOT_DIR/User"
    "-I$ROOT_DIR/Drivers"
    "-I$ROOT_DIR/Drivers/CMSIS/Device/ST/STM32F4xx/Include"
    "-I$ROOT_DIR/Drivers/CMSIS/Include"
    "-I$ROOT_DIR/Drivers/STM32F4xx_HAL_Driver/Inc"
    "-I$ROOT_DIR/Middlewares"
)

DEFINES=(
    "-DUSE_HAL_DRIVER"
    "-DSTM32F407xx"
)

# Cortex-M4 / 硬件浮点
CPU_FLAGS=(
    "-mcpu=cortex-m4"
    "-mthumb"
    "-mfpu=fpv4-sp-d16"
    "-mfloat-abi=hard"
)

CFLAGS=(
    "${CPU_FLAGS[@]}"
    "${DEFINES[@]}"
    "${INCLUDES[@]}"
    "-O1"
    "-g"
    "-Wall"
    "-ffunction-sections"
    "-fdata-sections"
    "-std=gnu11"
)

ASFLAGS=(
    "${CPU_FLAGS[@]}"
    "${DEFINES[@]}"
    "${INCLUDES[@]}"
    "-x" "assembler-with-cpp"
    "-g"
)

LDFLAGS=(
    "${CPU_FLAGS[@]}"
    "-T$LD_SCRIPT"
    "-Wl,--gc-sections"
    "-Wl,--no-warn-rwx-segments"
    "-Wl,-Map=$OUT_DIR/$TARGET.map"
    "--specs=nano.specs"
    "--specs=nosys.specs"
    "-Wl,--print-memory-usage"
    "-lc"
    "-lm"
    "-lnosys"
)

# ---------------------------------------------------------------------------
# 5. 编译
# ---------------------------------------------------------------------------
mkdir -p "$BUILD_DIR" "$OUT_DIR"

OBJECTS=()
for src in "${SOURCES[@]}"; do
    if [[ ! -f "$src" ]]; then
        echo "错误：源文件不存在 -> $src" >&2
        exit 1
    fi
    # 用相对路径生成唯一的目标文件名，避免重名
    rel="${src#$ROOT_DIR/}"
    obj="$BUILD_DIR/${rel//\//_}.o"
    OBJECTS+=("$obj")

    if [[ "$src" == *.s ]]; then
        echo "   汇编  $rel"
        "$CC" "${ASFLAGS[@]}" -c "$src" -o "$obj"
    else
        echo "   编译  $rel"
        "$CC" "${CFLAGS[@]}" -c "$src" -o "$obj"
    fi
done

# ---------------------------------------------------------------------------
# 6. 链接
# ---------------------------------------------------------------------------
echo ">> 链接 ..."
"$CC" "${OBJECTS[@]}" "${LDFLAGS[@]}" -o "$OUT_DIR/$TARGET.elf"

# ---------------------------------------------------------------------------
# 7. 生成 .bin / .hex
# ---------------------------------------------------------------------------
echo ">> 生成 .bin / .hex ..."
"$OBJCOPY" -O binary "$OUT_DIR/$TARGET.elf" "$OUT_DIR/$TARGET.bin"
"$OBJCOPY" -O ihex   "$OUT_DIR/$TARGET.elf" "$OUT_DIR/$TARGET.hex"

# ---------------------------------------------------------------------------
# 8. 汇总
# ---------------------------------------------------------------------------
echo ""
echo ">> 固件大小："
"$SIZE" "$OUT_DIR/$TARGET.elf"
echo ""
echo ">> 生成文件："
ls -lh "$OUT_DIR/$TARGET.elf" "$OUT_DIR/$TARGET.bin" "$OUT_DIR/$TARGET.hex" | awk '{print "   " $9 "  (" $5 ")"}'
echo ""
echo ">> 编译完成。"
