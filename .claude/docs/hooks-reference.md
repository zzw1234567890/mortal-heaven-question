
# 活动钩子 (Active Hooks)

钩子 (Hooks) 在 `.claude/settings.json` 中配置，并自动触发：

| 钩子 | 事件 | 触发条件 | 动作 |
| ---- | ----- | ------- | ------ |
| `validate-commit.sh` | PreToolUse (Bash) | `git commit` 命令 | 验证设计文档章节、JSON 数据文件、硬编码值、TODO 格式 |
| `validate-push.sh` | PreToolUse (Bash) | `git push` 命令 | 警告向受保护分支（develop/main）的推送 |
| `validate-assets.sh` | PostToolUse (Write/Edit) | 资源文件变更 | 检查 `assets/` 中文件的命名约定和 JSON 有效性 |
| `session-start.sh` | SessionStart | 会话开始 | 加载冲刺上下文、里程碑、Git 活动；检测并预览当前会话状态文件以进行恢复 |
| `detect-gaps.sh` | SessionStart | 会话开始 | 检测新项目（建议使用 /start）以及存在代码/原型时缺失的文档，建议使用 /reverse-document 或 /project-stage-detect |
| `pre-compact.sh` | PreCompact | 上下文压缩 | 在压缩前将会话状态（active.md、已修改文件、进行中的设计文档）转储到对话中，使其在摘要过程中得以保存 |
| `post-compact.sh` | PostCompact | 压缩之后 | 提醒 Claude 从 `active.md` 检查点恢复会话状态 |
| `notify.sh` | Notification | 通知事件 | 通过 PowerShell 显示 Windows 系统通知 (Toast Notification) |
| `session-stop.sh` | Stop | 会话结束 | 总结成果并更新会话日志 |
| `log-agent.sh` | SubagentStart | 子代理生成 | 审计追踪开始——记录子代理调用信息及时间戳 |
| `log-agent-stop.sh` | SubagentStop | 子代理停止 | 审计追踪结束——完成子代理记录 |
| `validate-skill-change.sh` | PostToolUse (Write/Edit) | 技能文件变更 | 建议在 `.claude/skills/` 文件被写入或编辑后运行 `/skill-test` |

钩子参考文档：`.claude/docs/hooks-reference/`
钩子输入模式文档：`.claude/docs/hooks-reference/hook-input-schemas.md`
