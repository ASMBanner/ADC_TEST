#!/usr/bin/env bash
# =============================================================================
# flash.sh —— 通过 J-Link 将固件烧录到 STM32F407 真机
#
# 前置：已用 ./build.sh 生成 Output/atk_f407.hex
# 用法：
#   ./flash.sh              # 烧录并复位运行
#   JLINK_DEVICE=STM32F407ZG JLINK_SPEED=4000 ./flash.sh
#
# 可通过环境变量覆盖默认连接参数：
#   JLINK_DEVICE  J-Link 设备名，默认 STM32F407ZG
#   JLINK_IFACE   调试接口，默认 SWD
#   JLINK_SPEED   接口速度 kHz，默认 4000
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEX="$ROOT_DIR/Output/atk_f407.hex"

DEVICE="${JLINK_DEVICE:-STM32F407ZG}"
IFACE="${JLINK_IFACE:-SWD}"
SPEED="${JLINK_SPEED:-4000}"
JLINK_EXE="${JLINK_EXE:-JLinkExe}"

if ! command -v "$JLINK_EXE" >/dev/null 2>&1; then
    echo "错误：找不到 $JLINK_EXE，请安装 SEGGER J-Link 软件并加入 PATH。" >&2
    exit 1
fi

if [[ ! -f "$HEX" ]]; then
    echo "错误：未找到 $HEX，请先执行 ./build.sh 生成固件。" >&2
    exit 1
fi

echo ">> J-Link 烧录：$DEVICE  $IFACE  ${SPEED}kHz"
echo ">> 固件：$HEX"

# J-Link Commander 脚本（临时文件，退出后自动清理）
CMDR_SCRIPT="$(mktemp -t jlink_flash.XXXXXX.jlink)"
trap 'rm -f "$CMDR_SCRIPT"' EXIT

cat > "$CMDR_SCRIPT" <<EOF
r
h
loadfile "$HEX"
r
g
qc
EOF

"$JLINK_EXE" \
    -device "$DEVICE" \
    -if "$IFACE" \
    -speed "$SPEED" \
    -autoconnect 1 \
    -CommanderScript "$CMDR_SCRIPT"
