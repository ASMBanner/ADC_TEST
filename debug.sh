#!/usr/bin/env bash
# =============================================================================
# debug.sh —— 通过 J-Link + GDB 对 STM32F407 真机进行在线调试
#
# 流程：启动 JLinkGDBServer -> 使用 arm-none-eabi-gdb 连接 -> 下载 ->
#       停在 main -> 进入交互式调试（可直接使用 gdb 命令）
#
# 用法：
#   ./debug.sh                      # 自动启动 GDB Server 并进入 GDB
#   GDB_PORT=2331 ./debug.sh        # 指定 GDB 端口
#   JLinkGDBServer 已在运行时，可直接：
#       GDB_SERVER_EXTERNAL=1 ./debug.sh
#
# 可用环境变量：
#   JLINK_DEVICE        设备名，默认 STM32F407ZG
#   JLINK_SPEED         接口速度 kHz，默认 4000
#   GDB_PORT            GDB Server 端口，默认 2331
#   GDB_SERVER_EXTERNAL =1 时不自动启动 GDB Server（复用已启动的实例）
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELF="$ROOT_DIR/Output/atk_f407.elf"

DEVICE="${JLINK_DEVICE:-STM32F407ZG}"
SPEED="${JLINK_SPEED:-4000}"
GDB_PORT="${GDB_PORT:-2331}"
GDB_SERVER_EXTERNAL="${GDB_SERVER_EXTERNAL:-0}"

TOOLCHAIN_BIN="${TOOLCHAIN_BIN:-/Users/banner/Work/K3PT/.tools/arm-gnu-toolchain-15.2.rel1-darwin-arm64-arm-none-eabi/bin}"
GDB="$TOOLCHAIN_BIN/arm-none-eabi-gdb"

if [[ ! -x "$GDB" ]]; then
    echo "错误：找不到 arm-none-eabi-gdb -> $GDB" >&2
    exit 1
fi

if [[ ! -f "$ELF" ]]; then
    echo "错误：未找到 $ELF，请先执行 ./build.sh 生成固件。" >&2
    exit 1
fi

SERVER_PID=""
if [[ "$GDB_SERVER_EXTERNAL" != "1" ]]; then
    echo ">> 启动 JLinkGDBServer：$DEVICE  SWD  ${SPEED}kHz  port=$GDB_PORT"
    JLinkGDBServer \
        -device "$DEVICE" \
        -if SWD \
        -speed "$SPEED" \
        -port "$GDB_PORT" \
        -singlerun \
        -silent &
    SERVER_PID=$!
    trap '[[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true' EXIT
    # 等待 GDB Server 监听端口就绪
    sleep 2
fi

echo ">> 连接 GDB 并下载固件 ..."
"$GDB" "$ELF" \
    -ex "set confirm off" \
    -ex "target extended-remote :$GDB_PORT" \
    -ex "monitor reset halt" \
    -ex "load" \
    -ex "monitor reset halt" \
    -ex "break main" \
    -ex "continue"
