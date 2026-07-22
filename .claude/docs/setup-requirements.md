
# 设置要求

本模板需要安装一些工具才能实现完整功能。如果缺少这些工具，所有钩子都会优雅地失败——不会有任何功能损坏，但您将失去验证功能。

## 必需工具

| 工具 | 用途 | 安装方式 |
| ---- | ---- | ---- |
| **Git** | 版本控制、分支管理 | [git-scm.com](https://git-scm.com/) |
| **Claude Code** | AI 代理命令行界面 | `npm install -g @anthropic-ai/claude-code` |

## 推荐工具

| 工具 | 被谁使用 | 用途 | 安装方式 |
| ---- | ---- | ---- | ---- |
| **jq** | 钩子（12 个中的 7 个） | 在提交、推送、资源、代理钩子中解析 JSON | 见下方 |
| **Python 3** | 钩子（12 个中的 2 个） | 数据文件的 JSON 验证 | [python.org](https://www.python.org/) |
| **Bash** | 所有钩子 | Shell 脚本执行 | 随 Git for Windows 附带 |

### 安装 jq

**Windows**（任选其一）：
```
winget install jqlang.jq
choco install jq
scoop install jq
```

**macOS**：
```
brew install jq
```

**Linux**：
```
sudo apt install jq     # Debian/Ubuntu
sudo dnf install jq     # Fedora
sudo pacman -S jq       # Arch
```

## 平台说明

### Windows
- Git for Windows 包含 **Git Bash**，它为 `settings.json` 中的所有钩子提供了 `bash` 命令
- 确保 Git Bash 已在您的 PATH 环境变量中（通过 Git 安装程序安装时为默认设置）
- 钩子使用 `bash .claude/hooks/[name].sh`——这在 Windows 上可以工作，因为 Claude Code 通过一个能够找到 `bash.exe` 的 shell 来调用命令

### macOS / Linux
- Bash 原生可用
- 通过您的包管理器安装 `jq` 以获得完整的钩子支持

## 验证您的设置

运行以下命令检查前置条件：

```bash
git --version          # 应显示 git 版本
bash --version         # 应显示 bash 版本
jq --version           # 应显示 jq 版本（可选）
python3 --version      # 应显示 python 版本（可选）
```

## 缺少可选工具的影响

| 缺少的工具 | 影响 |
| ---- | ---- |
| **jq** | 提交验证、推送保护、资源验证和代理审计钩子静默跳过其检查。提交和推送仍然正常工作。 |
| **Python 3** | 提交和资源钩子中的 JSON 数据文件验证被跳过。无效的 JSON 可以在没有警告的情况下提交。 |
| **两者都缺** | 所有钩子仍然无错误地执行（exit 0），但不提供任何验证。您将在没有安全网的情况下工作。 |

## 推荐 IDE

Claude Code 可与任何编辑器配合使用，但本模板针对以下环境进行了优化：
- **VS Code** + Claude Code 扩展
- **Cursor**（兼容 Claude Code）
- 基于终端的 Claude Code CLI
