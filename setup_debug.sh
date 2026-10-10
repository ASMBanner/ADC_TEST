#!/usr/bin/env bash
# =============================================================================
# setup_debug.sh —— 一键生成 VS Code + J-Link 调试配置（.vscode/*）
#
# 说明：.vscode 目录受 IDE 保护，仅允许用户本人创建/编辑，故以脚本形式提供。
#       运行一次即可生成 settings.json / tasks.json / launch.json。
#
# 用法：
#   ./setup_debug.sh
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSCODE_DIR="$ROOT_DIR/.vscode"

mkdir -p "$VSCODE_DIR"

# ---------------------------------------------------------------------------
# settings.json
# ---------------------------------------------------------------------------
cat > "$VSCODE_DIR/settings.json" <<'JSON'
{
    "cortex-debug.armToolchainPath": "/Users/banner/Work/K3PT/.tools/arm-gnu-toolchain-15.2.rel1-darwin-arm64-arm-none-eabi/bin",
    "cortex-debug.JLinkGDBServerPath": "/usr/local/bin/JLinkGDBServer"
}
JSON

# ---------------------------------------------------------------------------
# tasks.json
# ---------------------------------------------------------------------------
cat > "$VSCODE_DIR/tasks.json" <<'JSON'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build",
            "type": "shell",
            "command": "bash",
            "args": ["${workspaceFolder}/build.sh"],
            "options": { "cwd": "${workspaceFolder}" },
            "group": { "kind": "build", "isDefault": true },
            "problemMatcher": ["$gcc"],
            "presentation": { "reveal": "always", "panel": "shared", "clear": true }
        },
        {
            "label": "clean",
            "type": "shell",
            "command": "bash",
            "args": ["${workspaceFolder}/build.sh", "clean"],
            "options": { "cwd": "${workspaceFolder}" },
            "problemMatcher": []
        }
    ]
}
JSON

# ---------------------------------------------------------------------------
# launch.json
# ---------------------------------------------------------------------------
cat > "$VSCODE_DIR/launch.json" <<'JSON'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "J-Link 调试 (STM32F407)",
            "type": "cortex-debug",
            "request": "launch",
            "servertype": "jlink",
            "cwd": "${workspaceFolder}",
            "executable": "${workspaceFolder}/Output/atk_f407.elf",
            "device": "STM32F407ZG",
            "interface": "swd",
            "serverpath": "/usr/local/bin/JLinkGDBServer",
            "preLaunchTask": "build",
            "runToEntryPoint": "main",
            "showDevDebugOutput": "none"
        },
        {
            "name": "J-Link 调试 (不重新编译)",
            "type": "cortex-debug",
            "request": "launch",
            "servertype": "jlink",
            "cwd": "${workspaceFolder}",
            "executable": "${workspaceFolder}/Output/atk_f407.elf",
            "device": "STM32F407ZG",
            "interface": "swd",
            "serverpath": "/usr/local/bin/JLinkGDBServer",
            "runToEntryPoint": "main",
            "showDevDebugOutput": "none"
        }
    ]
}
JSON

echo ">> 已生成调试配置："
ls -l "$VSCODE_DIR"
echo ""
echo ">> 下一步：在 VS Code 中执行 Reload Window，然后按 F5 开始 J-Link 真机调试。"
