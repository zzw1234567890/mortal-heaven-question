
# 钩子输入/输出模式 (Hook Input/Output Schemas)

本文档记录了每个事件类型中，各个 Claude Code 钩子 (hook) 在标准输入 (stdin) 上接收到的 JSON 载荷。

## 工具使用前 (PreToolUse)

在工具执行前触发。可以**允许**（退出码 0）或**阻止**（退出码 2）。

### PreToolUse: Bash（终端命令）

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m 'feat: add player health system'",
    "description": "Commit changes with message",
    "timeout": 120000
  }
}
```

### PreToolUse: Write（写入）

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "src/gameplay/health.gd",
    "content": "extends Node\n..."
  }
}
```

### PreToolUse: Edit（编辑）

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "src/gameplay/health.gd",
    "old_string": "var health = 100",
    "new_string": "var health: int = 100"
  }
}
```

### PreToolUse: Read（读取）

```json
{
  "tool_name": "Read",
  "tool_input": {
    "file_path": "src/gameplay/health.gd"
  }
}
```

## 工具使用后 (PostToolUse)

在工具执行完成后触发。**无法阻止**（退出码对阻止操作无效）。标准错误 (stderr) 消息会作为警告显示。

### PostToolUse: Write（写入）

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "assets/data/enemy_stats.json",
    "content": "{\"goblin\": {\"health\": 50}}"
  },
  "tool_output": "File written successfully"
}
```

### PostToolUse: Edit（编辑）

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "assets/data/enemy_stats.json",
    "old_string": "\"health\": 50",
    "new_string": "\"health\": 75"
  },
  "tool_output": "File edited successfully"
}
```

## 子代理启动 (SubagentStart)

当通过任务 (Task) 工具生成子代理时触发。

```json
{
  "agent_name": "game-designer",
  "model": "sonnet",
  "description": "Design the combat healing mechanic"
}
```

## 会话启动 (SessionStart)

当 Claude Code 会话开始时触发。**无标准输入 (stdin) 输入**——钩子直接运行，其标准输出 (stdout) 会作为上下文展示给 Claude。

## 压缩前 (PreCompact)

在上下文窗口压缩之前触发。**无标准输入 (stdin) 输入**——钩子在压缩发生前运行以保存状态。

## 停止 (Stop)

当 Claude Code 会话结束时触发。**无标准输入 (stdin) 输入**——钩子用于清理和日志记录。

## 退出码参考 (Exit Code Reference)

| 退出码 | 含义 | 适用事件 |
|-----------|---------|-------------------|
| 0 | 允许 / 成功 | 所有事件 |
| 2 | 阻止（标准错误展示给 Claude） | 仅 PreToolUse |
| 其他 | 视为错误，工具继续执行 | 所有事件 |

## 备注

- 钩子通过**标准输入 (stdin)**（管道）接收 JSON。使用 `INPUT=$(cat)` 来捕获。
- 如果可用，使用 `jq` 解析；否则回退到 `grep` 以实现跨平台兼容。
- 在 Windows 上，`grep -P`（Perl 正则）通常不可用。请改用 `grep -E`（POSIX 扩展）。
- 路径分隔符在 Windows 上可能是 `\`。在比较路径时，使用 `sed 's|\\|/|g'` 进行归一化。
