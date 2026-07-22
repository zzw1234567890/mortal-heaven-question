
# settings.local.json 模板

创建 `.claude/settings.local.json` 用于存放**不应**提交到版本控制系统的个人覆盖配置。将其添加到 `.gitignore` 中。

## 示例 settings.local.json

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm *)",
      "Read",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force *)"
    ]
  }
}
```

## 权限模式

Claude Code 支持不同的权限模式。游戏开发推荐如下：

### 开发期间（默认）

使用**普通模式 (normal mode)**——Claude 在执行大多数命令前会征求许可。这对生产代码最安全。

### 原型制作期间

使用**自动接受模式 (auto-accept mode)**，并限定范围——在可丢弃的代码上实现更快的迭代。仅当在 `prototypes/` 目录中工作时使用此模式。

### 代码审查期间

使用**只读权限 (read-only)**——Claude 可以读取和搜索，但不能修改文件。

## 本地自定义钩子

您可以在 `settings.local.json` 中添加个人钩子，以扩展（而非覆盖）项目钩子。例如，在构建完成时添加通知：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'echo Session ended at $(date)'",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```
