---
name: wsl-terminology
description: Cross-platform environment — correct terms, paths and tools
---


# 规则：跨平台环境术语 (Cross-Platform Environment Terminology)

本工具集及其项目 **在 Windows、macOS 和 Linux 上运行**。绝不默认使用 WSL2，也绝不生成仅在 Linux 上工作的代码/配置。

## 全局路径 (Global Paths)

| 上下文 | 正确路径 |
|---------|--------------|
| OSK 凭据 | `~/.open-spec-kit/`（通过 `os.homedir()` 解析） |
| 技能/规则/智能体 | `~/.claude/`（由 Claude Code + Copilot 共享） |
| Claude Code 配置 | `~/.claude/settings.json` |
| VS Code 配置（Copilot） | 平台相关（参见 `install.js` 中的 `getVscodeSettingsPath()`） |

**绝不**写入绝对 Linux 路径（`/etc/`、`/home/*/`、`~/.bashrc`）。仅在路径派生自 `process.env.APPDATA` 时在 Windows 上使用 `%APPDATA%`。

## Shell 和 CLI

- Bash 命令适用于 **Git Bash / WSL / macOS / Linux**。它们不适用于普通的 PowerShell —— 跨平台脚本在需要在任意 shell 中运行时必须使用 Node.js 而非原始 bash。
- 本套件的工具：**`open-spec-kit`**（通过 `cli/` 中的 `npm install -g .` 实现全局二进制）。绝不要使用 `osk` —— 它不存在。
- 检测 shell：在 Node.js 中使用 `process.platform === 'win32'`。

## 不要生成 (Do Not Generate)

- 将被 Windows 用户调用的 `#!/bin/bash` 脚本
- 当 `path.join()` 能正确解析时，使用硬编码 `/` 的路径
- 当特性至关重要时，没有跨平台 `.js` 等效项的 `.sh` 文件
- 默认引用 `wsl`、`WSL2`、`Ubuntu WSL` —— 仅在文档明确聚焦 Linux 时

## 如果必须使用 WSL (If WSL Is Required)

明确记录："此特性需要 Linux 或 WSL2，因为它依赖于 X"。绝不假设。
